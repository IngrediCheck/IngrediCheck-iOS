import SwiftUI
import AVFoundation
import UIKit
import Combine
import PhotosUI

struct BarcodeCameraPreview: UIViewRepresentable {

    @ObservedObject var cameraManager: BarcodeCameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = UIScreen.main.bounds
            view.layer.addSublayer(previewLayer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = cameraManager.previewLayer {
            if previewLayer.superlayer !== uiView.layer {
                uiView.layer.addSublayer(previewLayer)
            }
            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            previewLayer.frame = uiView.bounds
        }
    }
}

struct CameraScreen: View {
    
    @StateObject var camera = BarcodeCameraManager()
    @State private var cameraStatus: AVAuthorizationStatus = .notDetermined
    @Environment(\.scenePhase) var scenePhase
    @State private var isCaptured: Bool = false
    @State private var overlayRect: CGRect = .zero
    @State private var overlayContainerSize: CGSize = .zero
    @State private var codes: [String] = []
    @State private var scrollTargetCode: String?
    @State private var isUserDragging: Bool = false
    @State private var lastUserDragAt: Date? = nil
    @State private var currentCenteredCode: String? = nil
    @State private var cardCenterData: [CardCenterPreferenceData] = []
    @State private var mode: CameraMode = .scanner
    @State private var capturedPhoto: UIImage? = nil
    @State private var capturedPhotoHistory: [UIImage] = []
    @State private var galleryLimitHit: Bool = false
    @State private var isShowingPhotoPicker: Bool = false
    @State private var isShowingPhotoModeGuide: Bool = false
    @State private var showRetryCallout: Bool = false
    @State private var toastState: ToastScanState = .scanning
    @State private var selectedProduct: DTO.Product? = nil
    @State private var selectedMatchStatus: DTO.ProductRecommendation? = nil
    @State private var selectedIngredientRecommendations: [DTO.IngredientRecommendation]? = nil
    @State private var isProductDetailPresented: Bool = false
    @State private var photoFlashEnabled: Bool = false
    
    private func updateToastState() {
        // When in photo mode, show a dedicated guidance toast
        if mode == .photo {
            toastState = .photoGuide
            return
        }
        
        // Only show these scan-related toasts in scanner mode
        guard mode == .scanner else {
            toastState = .scanning
            return
        }
        
        // No codes yet: user is aligning/scanning. Only consider the centered card.
        guard let activeCode = currentCenteredCode, !activeCode.isEmpty else {
            toastState = .scanning
            return
        }
        
        // If we have a cached analysis result for this barcode, derive state from it.
        if let result = BarcodeScanAnalysisService.cachedResult(for: activeCode) {
            if result.notFound {
                toastState = .notIdentified
                return
            }
            
            if let match = result.matchStatus {
                switch match {
                case .match:
                    toastState = .match
                case .notMatch:
                    toastState = .notMatch
                case .needsReview:
                    toastState = .uncertain
                }
                return
            }
            
            if result.product != nil && result.ingredientRecommendations == nil {
                // Product known but ingredients/recs still streaming in
                toastState = .analyzing
                return
            }
            
            if let error = result.errorMessage, !error.isEmpty {
                // Generic fallback: suggest retry
                toastState = .retry
                return
            }
            
            // Default when product exists but no final match status yet
            if result.product != nil {
                toastState = .analyzing
                return
            }
        } else {
            // We have a code but no cached result yet: barcode extracted, fetching data.
            toastState = .extractionSuccess
            return
        }
        
        // Fallback
        toastState = .scanning
    }
    private func nearestCenteredCode(to centerX: CGFloat, in values: [CardCenterPreferenceData]) -> String? {
        guard !values.isEmpty else { return nil }
        return values.min(by: { abs($0.center - centerX) < abs($1.center - centerX) })?.code
    }
    
    var body: some View {
        ZStack {
#if targetEnvironment(simulator)
            Color(.systemGray5)
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Camera not available in Preview/Simulator")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                )
#endif
            BarcodeCameraPreview(cameraManager: camera)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .onAppear {
                    let status = AVCaptureDevice.authorizationStatus(for: .video)
                    cameraStatus = status
                    switch status {
                    case .authorized:
                        camera.startSession()
                    case .notDetermined:
                        requestCameraAccess { granted in
                            cameraStatus = granted ? .authorized : .denied
                            if granted { camera.startSession() }
                        }
                    case .denied, .restricted:
                        break
                    @unknown default:
                        break
                    }
                    camera.scanningEnabled = (mode == .scanner)
                    isCaptured = UIScreen.main.isCaptured
                    updateToastState()
                }
                .onDisappear { camera.stopSession() }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        if cameraStatus == .authorized { camera.startSession() }
                    } else if newPhase == .background {
                        camera.stopSession()
                    }
                }
                .onChange(of: mode) { newMode in
                    camera.scanningEnabled = (newMode == .scanner)
                    if newMode == .photo {
                        let key = "hasShownPhotoModeGuide"
                        let hasShown = UserDefaults.standard.bool(forKey: key)
                        if !hasShown {
                            isShowingPhotoModeGuide = true
                            UserDefaults.standard.set(true, forKey: key)
                        }
                    }
                    updateToastState()
                }
                .onChange(of: camera.isSessionRunning) { running in
                    if running {
                        camera.updateRectOfInterest(overlayRect: overlayRect, containerSize: overlayContainerSize)
                    }
                }
                .onReceive(camera.$scannedBarcode.compactMap { $0 }) { code in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        if let idx = codes.firstIndex(of: code) {
                            scrollTargetCode = codes[idx]
                        } else {
                            codes.insert(code, at: 0)
                            scrollTargetCode = code
                        }
                    }
                    updateToastState()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                    isCaptured = UIScreen.main.isCaptured
                }
                .onChange(of: isProductDetailPresented) { presented in
                    // When the Product Detail sheet is shown, pause the camera
                    // session to reduce memory pressure. Resume when the sheet
                    // is dismissed.
                    if presented {
                        camera.stopSession()
                    } else if cameraStatus == .authorized && scenePhase == .active {
                        camera.startSession()
                    }
                }
            
            if mode == .scanner {
                ScannerOverlay(onRectChange: { rect, size in
                    overlayRect = rect
                    overlayContainerSize = size
                    camera.updateRectOfInterest(overlayRect: rect, containerSize: size)
                })
                .environmentObject(camera)
            } else {
                // Photo mode overlay: fixed vertical layout:
                // - 213 pt from top to top of capture guide frame
                // - 26 pt gap below frame, then result cards (LazyHStack)
                GeometryReader { geo in
                    let centerX = geo.size.width / 2
                    let guideTop: CGFloat = 213
                    let guideSize: CGFloat = 244
                    let cardHeight: CGFloat = 120
                    let cardTop: CGFloat = guideTop + guideSize + 26
                    let guideCenterY = guideTop + guideSize / 2
                    let cardCenterY = cardTop + cardHeight / 2
                    
                    ZStack {
                        // Capture guide frame
                        Image("imagecaptureUI")
                            .resizable()
                            .frame(width: guideSize, height: guideSize)
                            .position(x: centerX, y: guideCenterY)
                        
                        // Result cards directly under the frame
                        if !capturedPhotoHistory.isEmpty {
                            if #available(iOS 17.0, *) {
                                // iOS 17+ smooth snapping carousel
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 8) {
                                        ForEach(Array(capturedPhotoHistory.indices), id: \.self) { idx in
                                            let image = capturedPhotoHistory[idx]
                                            PhotoContentView4(image: image)
                                                .transition(.opacity)
                                        }
                                    }
                                    .scrollTargetLayout() // each card acts as a scroll target
                                    .padding(.horizontal, max((geo.size.width - 300) / 2, 0))
                                }
                                .scrollTargetBehavior(.viewAligned) // snap nearest card to center
                                .frame(height: cardHeight)
                                .position(x: centerX, y: cardCenterY)
                            } else {
                                // iOS 16 and earlier: keep existing non-snapping behavior
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 8) {
                                        ForEach(Array(capturedPhotoHistory.indices), id: \.self) { idx in
                                            let image = capturedPhotoHistory[idx]
                                            PhotoContentView4(image: image)
                                                .transition(.opacity)
                                        }
                                    }
                                    .padding(.horizontal, max((geo.size.width - 300) / 2, 0))
                                }
                                .frame(height: cardHeight)
                                .position(x: centerX, y: cardCenterY)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            
            VStack {
                HStack {
                    BackButton()
                    Spacer()
                    if mode == .scanner {
                        Flashcapsul(isScannerMode: true)
                    }
                }
                .padding(.horizontal,20)
                .padding(.bottom,42)
                
                //                cameraGuidetext()
                tostmsg(state: toastState)
                    .onAppear {
                        updateToastState()
                    }
                Spacer()
                if mode == .photo {
                    HStack {
                        Flashcapsul(
                            isScannerMode: false,
                            onTogglePhotoFlash: { enabled in
                                photoFlashEnabled = enabled
                            }
                        )
                        
                        Spacer()
                        
                        // MARK: - Image Capturing Button
                        // Center: Capture photo button - captures a photo from the camera and adds it to the photo history
                        Button(action: {
                            camera.capturePhoto(useFlash: photoFlashEnabled) { image in
                                if let image = image {
                                    capturedPhoto = image
                                    capturedPhotoHistory.insert(image, at: 0)
                                    if capturedPhotoHistory.count > 10 {
                                        capturedPhotoHistory.removeLast(capturedPhotoHistory.count - 10)
                                    }
                                }
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 50, height: 50)
                                Circle()
                                    .stroke(Color.white.opacity(0.4), lineWidth: 3)
                                    .frame(width: 63, height: 63)
                            }
                        }
                        Spacer()
                        
                        // Right: Gallery button
                        Button(action: {
                            isShowingPhotoPicker = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.thinMaterial.opacity(0.4))
                                    .frame(width: 48, height: 48)
                                Image("gallary1")
                                    .resizable()
                                    .frame(width: 24.27, height: 21.19)
                                    .padding(.top ,4)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .padding(.bottom ,16)
                }
                CameraSwipeButton(mode: $mode, showRetryCallout: $showRetryCallout)
                    .padding(.bottom ,20)
            }
            .zIndex(2)
            
            if mode == .scanner {
                VStack {
                    Spacer()
                    
                    ScrollViewReader { proxy in
                        // Always use the same layout; when there are no codes yet,
                        // show a single placeholder card with an empty code.
                        let screenCenterX = UIScreen.main.bounds.width / 2
                        let displayCodes = codes.isEmpty ? [""] : codes
                        let maxDistance: CGFloat = 220        // distance after which we clamp to minimum scale
                        let minScale: CGFloat = 97.0 / 120.0  // off-center cards should be about 97pt tall
                        
                        if #available(iOS 17.0, *) {
                            // iOS 17+ horizontal carousel (no implicit snapping)
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 8) {
                                    ForEach(displayCodes, id: \.self) { code in
                                        GeometryReader { geo in
                                            let midX = geo.frame(in: .global).midX
                                            let distance = abs(midX - screenCenterX)
                                            let t = min(distance / maxDistance, 1)
                                            let scale = max(minScale, 1 - (1 - minScale) * t)
                                            
                                            ZStack {
                                                BarcodeDataCard(
                                                    code: code,
                                                    onRetryShown: {
                                                        showRetryCallout = true
                                                    },
                                                    onRetryHidden: {
                                                        showRetryCallout = false
                                                    },
                                                    onResultUpdated: {
                                                        updateToastState()
                                                    },
                                                    onTap: { product, matchStatus, recs in
                                                        selectedProduct = product
                                                        selectedMatchStatus = matchStatus
                                                        selectedIngredientRecommendations = recs
                                                        isProductDetailPresented = true
                                                    }
                                                )
                                                .scaleEffect(x: 1.0, y: scale, anchor: .center)
                                                .animation(.easeInOut(duration: 0.2), value: scale)
                                            }
                                            .background(
                                                Color.clear.preference(
                                                    key: CardCenterPreferenceKey.self,
                                                    value: [CardCenterPreferenceData(code: code, center: midX)]
                                                )
                                            )
                                        }
                                        .frame(width: 300, height: 120)
                                        .id(code)
                                        .transition(.opacity)
                                    }
                                }
                                .scrollTargetLayout() // mark each card as a scroll target
                                .padding(.horizontal, max((UIScreen.main.bounds.width - 300) / 2, 0))
                            }
                            .onChange(of: scrollTargetCode) { target in
                                guard let target else { return }
                                withAnimation(.easeInOut) {
                                    proxy.scrollTo(target, anchor: .center)
                                }
                            }
                            .onPreferenceChange(CardCenterPreferenceKey.self) { values in
                                cardCenterData = values
                                let centerX = UIScreen.main.bounds.width / 2
                                if let nearest = nearestCenteredCode(to: centerX, in: values) {
                                    currentCenteredCode = nearest
                                    updateToastState()
                                }
                            }
                        } else {
                            // iOS 16 and earlier: horizontal carousel without extra snapping gesture
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 8) {
                                    ForEach(displayCodes, id: \.self) { code in
                                        GeometryReader { geo in
                                            let midX = geo.frame(in: .global).midX
                                            let distance = abs(midX - screenCenterX)
                                            let t = min(distance / maxDistance, 1) // 0 at center, -> 1 at/maxDistance
                                            let scale = max(minScale, 1 - (1 - minScale) * t)
                                            
                                            ZStack {
                                                BarcodeDataCard(
                                                    code: code,
                                                    onRetryShown: {
                                                        showRetryCallout = true
                                                    },
                                                    onRetryHidden: {
                                                        showRetryCallout = false
                                                    },
                                                    onTap: { product, matchStatus, recs in
                                                        selectedProduct = product
                                                        selectedMatchStatus = matchStatus
                                                        selectedIngredientRecommendations = recs
                                                        isProductDetailPresented = true
                                                    }
                                                )
                                                .scaleEffect(x: 1.0, y: scale, anchor: .center)
                                                .animation(.easeInOut(duration: 0.2), value: scale)
                                            }
                                            .background(
                                                Color.clear.preference(
                                                    key: CardCenterPreferenceKey.self,
                                                    value: [CardCenterPreferenceData(code: code, center: midX)]
                                                )
                                            )
                                        }
                                        .frame(width: 300, height: 120)
                                        .id(code)
                                        .transition(.opacity)
                                    }
                                }
                                .padding(.horizontal, max((UIScreen.main.bounds.width - 300) / 2, 0))
                            }
                            .onChange(of: scrollTargetCode) { target in
                                guard let target else { return }
                                // Suppress auto-scroll if user is actively dragging or just dragged recently
                                let recentlyDragged: Bool = {
                                    guard let last = lastUserDragAt else { return false }
                                    return Date().timeIntervalSince(last) < 1.0
                                }()
                                guard !isUserDragging && !recentlyDragged else { return }
                                withAnimation(.easeInOut) { proxy.scrollTo(target, anchor: .center) }
                            }
                            .onPreferenceChange(CardCenterPreferenceKey.self) { values in
                                cardCenterData = values
                                let centerX = UIScreen.main.bounds.width / 2
                                if let nearest = nearestCenteredCode(to: centerX, in: values) {
                                    currentCenteredCode = nearest
                                    updateToastState()
                                }
                            }
                        }
                    }
                    .padding(.top, 243)
                }
                
                if cameraStatus == .denied || cameraStatus == .restricted {
                    VStack(spacing: 12) {
                        Text("Camera access is required")
                            .font(.headline)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                //            VStack {
                //                Spacer()
                ////                HStack {
                ////                    if let code = camera.scannedBarcode {
                ////                        Text("Scanned: \(code)")
                ////                            .font(.footnote)
                ////                            .padding(6)
                ////                            .background(.black.opacity(0.5))
                ////                            .foregroundColor(.white)
                ////                            .clipShape(RoundedRectangle(cornerRadius: 6))
                ////                    }
                ////                    if isCaptured {
                ////                        Text("Screen Recording/Mirroring Detected – iOS hides camera")
                ////                            .font(.footnote)
                ////                            .padding(6)
                ////                            .background(.red.opacity(0.7))
                ////                            .foregroundColor(.white)
                ////                            .clipShape(RoundedRectangle(cornerRadius: 6))
                ////                    }
                ////                    Spacer()
                ////                }
                //            }
                //            .padding()
            }
            
            if isShowingPhotoModeGuide {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut) {
                                isShowingPhotoModeGuide = false
                            }
                        }
                    
                    VStack {
                        Spacer()
                        
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 24) {
                                VStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(.systemGray4))
                                        .frame(width: 72, height: 4)
                                        .padding(.top, 12)
                                    
                                    Text("Capture your product 📸")
                                        .font(NunitoFont.bold.size(24))
                                        .foregroundColor(.grayScale150)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                    
                                    Text("We’ll guide you through a few angles so our AI can identify the product and its ingredients accurately.")
                                        .font(ManropeFont.medium.size(12))
                                        .foregroundColor(Color(.grayScale120))
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                }
                                ZStack{
                                    Image("systemuiconscapture")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 187, height: 187)
                                    Image("takeawafood")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 94, height: 110)
                                }
                                
                                Text("You’ll take around 5 photos — front, back, barcode, and ingredient list.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(.grayScale110))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 16)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Button(action: {
                                withAnimation(.easeInOut) {
                                    isShowingPhotoModeGuide = false
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(.lightGray))
                                    .padding(12)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                            .padding(.trailing, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 431)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .shadow(radius: 20)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 0)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: isShowingPhotoModeGuide)
                .zIndex(3)
            }
        }
        .fullScreenCover(isPresented: $isProductDetailPresented) {
            if let product = selectedProduct {
                ProductDetailView(
                    product: product,
                    matchStatus: selectedMatchStatus,
                    ingredientRecommendations: selectedIngredientRecommendations,
                    isPlaceholderMode: false,
                    clientActivityId: nil,
                    favorited: false
                )
            } else {
                ProductDetailView(isPlaceholderMode: true)
            }
        }
        .sheet(isPresented: $isShowingPhotoPicker) {
            PhotoPicker(images: $capturedPhotoHistory,
                        didHitLimit: $galleryLimitHit,
                        maxTotalCount: 10)
        }
    }
    
    
    // MARK: - Photo Picker for gallery selection
    
    struct PhotoPicker: UIViewControllerRepresentable {
        
        @Environment(\.presentationMode) var presentationMode
        @Binding var images: [UIImage]
        @Binding var didHitLimit: Bool
        var maxTotalCount: Int = 10
        
        func makeUIViewController(context: Context) -> PHPickerViewController {
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = maxTotalCount
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = context.coordinator
            return picker
        }
        
        func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
            // no-op
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        class Coordinator: NSObject, PHPickerViewControllerDelegate {
            let parent: PhotoPicker
            
            init(_ parent: PhotoPicker) {
                self.parent = parent
            }
            
            func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                parent.presentationMode.wrappedValue.dismiss()
                
                guard !results.isEmpty else { return }
                
                for result in results {
                    let provider = result.itemProvider
                    guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                    
                    provider.loadObject(ofClass: UIImage.self) { object, _ in
                        guard let uiImage = object as? UIImage else { return }
                        DispatchQueue.main.async {
                            if self.parent.images.count < self.parent.maxTotalCount {
                                // Insert newest images at the front of the history
                                self.parent.images.insert(uiImage, at: 0)
                            } else {
                                // We hit the global limit of 10 images; show a warning in the parent view.
                                self.parent.didHitLimit = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    struct CardCenterPreferenceData: Equatable {
        let code: String
        let center: CGFloat
    }
    
    struct CardCenterPreferenceKey: PreferenceKey {
        static var defaultValue: [CardCenterPreferenceData] = []
        
        static func reduce(value: inout [CardCenterPreferenceData], nextValue: () -> [CardCenterPreferenceData]) {
            value.append(contentsOf: nextValue())
        }
    }
    // MARK: - Photo card matching ContentView4 style
    
    struct PhotoContentView4: View {
        let image: UIImage
        
        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.thinMaterial.opacity(0.2))
                    .frame(width: 300, height: 120)
                
                HStack {
                    HStack(spacing: 47) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.thinMaterial.opacity(0.4))
                                .frame(width: 68, height: 92)
                            
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 64, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.thinMaterial.opacity(0.4))
                            .frame(width: 185, height: 25)
                            .opacity(0.3)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.thinMaterial.opacity(0.4))
                            .frame(width: 132, height: 20)
                            .padding(.bottom, 7)
                        
                        RoundedRectangle(cornerRadius: 52)
                            .fill(.thinMaterial.opacity(0.4))
                            .frame(width: 79, height: 24)
                    }
                }
            }
        }
    }

}
