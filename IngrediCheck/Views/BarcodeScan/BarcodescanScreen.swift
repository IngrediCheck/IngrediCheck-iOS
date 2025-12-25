import SwiftUI
import AVFoundation
import UIKit
import Combine
import PhotosUI
import Supabase

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

// Photo scan session structure to track multiple sessions
struct PhotoScanSession: Identifiable {
    let id: String // scanId
    var photos: [UIImage]
    var productInfo: ProductInfo?
    
    init(scanId: String) {
        self.id = scanId
        self.photos = []
        self.productInfo = nil
    }
}

struct CameraScreen: View {
    
    @StateObject var camera = BarcodeCameraManager()
    @Environment(WebService.self) var webService
    @StateObject private var photoScanStore = PhotoScanStore()
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
    @State private var photoScanSessions: [PhotoScanSession] = [] // Array of scan sessions (like codes array for barcode)
    @State private var currentSessionId: String? = nil // Current active session scanId
    @State private var scrollTargetSessionId: String? = nil // Target session to scroll to (like scrollTargetCode for barcode)
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
    
    @State private var showProTipCard: Bool = false
    
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
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    print("📸 [CameraScreen] onAppear called")
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    
                    // Set webService in photoScanStore
                    print("[CameraScreen] Setting webService in photoScanStore...")
                    photoScanStore.setWebService(webService)
                    
                    let status = AVCaptureDevice.authorizationStatus(for: .video)
                    print("[CameraScreen] Camera authorization status: \(status.rawValue)")
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
                        
                        let cardKey = "hasSeenProTipCard"
                        let hasSeenCard = UserDefaults.standard.bool(forKey: cardKey)
                        if !hasSeenCard {
                            showProTipCard = true
                            UserDefaults.standard.set(true, forKey: cardKey)
                        } else {
                            showProTipCard = false
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
                .onChange(of: photoScanStore.scanDetails) { scanDetails in
                    // Update current session's productInfo when scanDetails changes
                    if let sessionId = currentSessionId ?? photoScanStore.scanId,
                       let sessionIndex = photoScanSessions.firstIndex(where: { $0.id == sessionId }),
                       let scanDetails = scanDetails {
                        // Update productInfo from scanDetails
                        photoScanSessions[sessionIndex].productInfo = photoScanStore.productInfo
                        print("📸 [CameraScreen] Updated productInfo for session: \(sessionId)")
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
                    let guideTop: CGFloat = 180
                    let guideSize: CGFloat = 244
                    let cardHeight: CGFloat = 120
                    let cardTop: CGFloat = guideTop + guideSize + 26
                    let guideCenterY = guideTop + guideSize / 2
                    let cardCenterY = cardTop + cardHeight / 2
                    
                    ZStack {
                        // Capture guide frame
                        Image("photo-scan-overlay-capture")
                            .resizable()
                            .frame(width: guideSize, height: guideSize)
                            .position(x: centerX, y: guideCenterY)
                        
                        // Result cards directly under the frame
                        if !photoScanSessions.isEmpty {
                            
                            if #available(iOS 17.0, *) {
                                // iOS 17+ smooth snapping carousel
                                ScrollViewReader { proxy in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHStack(spacing: 8) {
                                            ForEach(photoScanSessions) { session in
                                                // Show all photos from session with stacked images
                                                PhotoContentView4(photos: session.photos, productInfo: session.productInfo)
                                                    .transition(.opacity)
                                                    .id(session.id)
                                            }
                                        }
                                        .scrollTargetLayout() // each card acts as a scroll target
                                        .padding(.horizontal, max((geo.size.width - 300) / 2, 0))
                                    }
                                    .onChange(of: scrollTargetSessionId) { targetId in
                                        guard let targetId else { return }
                                        withAnimation(.easeInOut) {
                                            proxy.scrollTo(targetId, anchor: .center)
                                        }
                                    }
                                    .overlay(
                                    Button(action: {
                                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                                        print("📸 [CameraScreen] Plus button tapped - starting new session...")
                                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                                        
                                        // Start a new scan session (keep previous sessions)
                                        currentSessionId = nil // Reset current session
                                        Task {
                                            await photoScanStore.startNewScan()
                                            // After scan is created, add new session to array
                                            if let newScanId = photoScanStore.scanId {
                                                currentSessionId = newScanId
                                                let newSession = PhotoScanSession(scanId: newScanId)
                                                photoScanSessions.insert(newSession, at: 0) // Add at beginning
                                            }
                                        }
                                    }) {
                                        RoundedRectangle(cornerRadius: 20)
                                            .frame(width: 30, height: cardHeight)
                                            .foregroundStyle(.ultraThinMaterial)
                                            .opacity(0.8)
                                            .overlay(
                                                Image("photo-screen-add-card")
                                                    .resizable()
                                                    .frame(width: 16, height: 16)
                                                    .padding(.trailing, 4)
                                                , alignment: .trailing
                                            )
                                            .offset(x: -8)
                                    }
                                    .disabled(photoScanStore.isCreatingScan)
                                    , alignment: .leading
                                )
                                .scrollTargetBehavior(.viewAligned) // snap nearest card to center
                                .frame(height: cardHeight)
                                .position(x: centerX, y: cardCenterY)
                                }
                            } else {
                                // iOS 16 and earlier: keep existing non-snapping behavior
                                ScrollViewReader { proxy in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHStack(spacing: 8) {
                                            ForEach(photoScanSessions) { session in
                                                // Show all photos from session with stacked images
                                                PhotoContentView4(photos: session.photos, productInfo: session.productInfo)
                                                    .transition(.opacity)
                                                    .id(session.id)
                                            }
                                        }
                                        .padding(.horizontal, max((geo.size.width - 300) / 2, 0))
                                    }
                                    .onChange(of: scrollTargetSessionId) { targetId in
                                        guard let targetId else { return }
                                        withAnimation(.easeInOut) {
                                            proxy.scrollTo(targetId, anchor: .center)
                                        }
                                    }
                                    .overlay(
                                    Button(action: {
                                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                                        print("📸 [CameraScreen] Plus button tapped - starting new session...")
                                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                                        
                                        // Start a new scan session (keep previous sessions)
                                        currentSessionId = nil // Reset current session
                                        Task {
                                            await photoScanStore.startNewScan()
                                            // After scan is created, add new session to array
                                            if let newScanId = photoScanStore.scanId {
                                                currentSessionId = newScanId
                                                let newSession = PhotoScanSession(scanId: newScanId)
                                                photoScanSessions.insert(newSession, at: 0) // Add at beginning
                                            }
                                        }
                                    }) {
                                        RoundedRectangle(cornerRadius: 20)
                                            .frame(width: 30, height: cardHeight)
                                            .foregroundStyle(.ultraThinMaterial)
                                            .opacity(0.8)
                                            .overlay(
                                                Image("photo-screen-add-card")
                                                    .resizable()
                                                    .frame(width: 16, height: 16)
                                                    .padding(.trailing, 4)
                                                , alignment: .trailing
                                            )
                                            .offset(x: -8)
                                    }
                                    .disabled(photoScanStore.isCreatingScan)
                                    , alignment: .leading
                                )
                                .frame(height: cardHeight)
                                .position(x: centerX, y: cardCenterY)
                                }
                            }
                        } else if showProTipCard {
                            ProTipCard {
                                withAnimation(.easeInOut) {
                                    isShowingPhotoModeGuide = true
                                }
                            }
                            .position(x: centerX, y: cardCenterY)
                        } else {
                            BarcodeDataCard(code: "")
                                .position(x: centerX, y: cardCenterY)
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
                        // Center: Capture photo button - captures a photo from the camera and adds it to the current session
                        Button(action: {
        camera.capturePhoto(useFlash: photoFlashEnabled) { image in
            if let image = image {
                capturedPhoto = image
                
                // IMMEDIATELY add photo to UI to show loading card right away
                // This happens synchronously on main thread before any async operations
                let targetSessionId = currentSessionId ?? photoScanStore.scanId
                
                if targetSessionId == nil {
                    // No session exists - create a temporary session immediately to show loading card
                    // We'll replace it with the real scanId once it's created
                    let tempSessionId = UUID().uuidString
                    currentSessionId = tempSessionId
                    var newSession = PhotoScanSession(scanId: tempSessionId)
                    newSession.photos.insert(image, at: 0)
                    photoScanSessions.insert(newSession, at: 0)
                    
                    // Scroll to the new session
                    withAnimation(.easeInOut) {
                        scrollTargetSessionId = tempSessionId
                    }
                } else {
                    // Session exists - add photo immediately
                    if let sessionIndex = photoScanSessions.firstIndex(where: { $0.id == targetSessionId }) {
                        photoScanSessions[sessionIndex].photos.insert(image, at: 0)
                        // Limit photos per session
                        if photoScanSessions[sessionIndex].photos.count > 10 {
                            photoScanSessions[sessionIndex].photos.removeLast(photoScanSessions[sessionIndex].photos.count - 10)
                        }
                    } else if let sessionId = targetSessionId {
                        // Session not found in array, create it immediately
                        var newSession = PhotoScanSession(scanId: sessionId)
                        newSession.photos.insert(image, at: 0)
                        photoScanSessions.insert(newSession, at: 0)
                        currentSessionId = sessionId
                        
                        // Scroll to the new session
                        withAnimation(.easeInOut) {
                            scrollTargetSessionId = sessionId
                        }
                    }
                }
                
                // Now start async upload operations
                Task {
                    // Determine which session to use: currentSessionId takes priority, then photoScanStore.scanId
                    let targetSessionId = currentSessionId ?? photoScanStore.scanId
                    
                    // If no session exists (or we have a temp session), create one first
                    if photoScanStore.scanId == nil {
                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                        print("📸 [CameraScreen] No active scan, starting new scan...")
                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                        // Wait for scan to be created before uploading
                        await photoScanStore.startNewScan()
                        
                        // Check if scan was created successfully
                        if let newScanId = photoScanStore.scanId {
                            print("📸 [CameraScreen] ✅ Scan created, now uploading image...")
                            
                            // Update the temporary session with the real scanId
                            if let tempSessionId = currentSessionId,
                               let sessionIndex = photoScanSessions.firstIndex(where: { $0.id == tempSessionId }) {
                                // Replace temp session with real session (create new one since id is immutable)
                                let existingSession = photoScanSessions[sessionIndex]
                                var newSession = PhotoScanSession(scanId: newScanId)
                                newSession.photos = existingSession.photos
                                newSession.productInfo = existingSession.productInfo
                                photoScanSessions[sessionIndex] = newSession
                                currentSessionId = newScanId
                                
                                // Update scroll target
                                withAnimation(.easeInOut) {
                                    scrollTargetSessionId = newScanId
                                }
                            } else {
                                // If temp session wasn't found, create new one
                                currentSessionId = newScanId
                                if let sessionIndex = photoScanSessions.firstIndex(where: { $0.photos.contains(image) }) {
                                    // Replace existing session with new scanId
                                    let existingSession = photoScanSessions[sessionIndex]
                                    var newSession = PhotoScanSession(scanId: newScanId)
                                    newSession.photos = existingSession.photos
                                    newSession.productInfo = existingSession.productInfo
                                    photoScanSessions[sessionIndex] = newSession
                                } else {
                                    var newSession = PhotoScanSession(scanId: newScanId)
                                    newSession.photos.insert(image, at: 0)
                                    photoScanSessions.insert(newSession, at: 0)
                                }
                            }
                            
                            await photoScanStore.uploadImage(image: image)
                        } else {
                            print("📸 [CameraScreen] ❌ Failed to create scan, cannot upload image")
                        }
                    } else {
                        // Continue in existing session (even if productInfo is already loaded)
                        // This allows adding more photos to the same product for better analysis
                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                        print("📸 [CameraScreen] Photo captured, continuing in existing session...")
                        print("📸 [CameraScreen] Session ID: \(targetSessionId ?? "nil")")
                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                        
                        // Ensure photoScanStore.scanId matches the current session for upload
                        if let sessionId = targetSessionId {
                            photoScanStore.scanId = sessionId
                            currentSessionId = sessionId // Keep currentSessionId in sync
                        }
                        
                        // Upload to existing scan session (multiple photos in same session)
                        await photoScanStore.uploadImage(image: image)
                    }
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
                        let displayCodes = codes.isEmpty ? [""] : codes
                        let screenCenterX = UIScreen.main.bounds.width / 2
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
                    isPlaceholderMode: false
                )
            } else {
                ProductDetailView(isPlaceholderMode: true)
            }
        }
        .sheet(isPresented: $isShowingPhotoPicker) {
            // PhotoPicker for gallery selection - will add to current session
            // Create a binding that adds to current session when images are selected
            PhotoPicker(
                images: Binding(
                    get: {
                        // Return current session's photos if available
                        if let sessionId = currentSessionId ?? photoScanStore.scanId,
                           let session = photoScanSessions.first(where: { $0.id == sessionId }) {
                            return session.photos
                        }
                        return []
                    },
                    set: { newImages in
                        // Add selected images to current session
                        if let sessionId = currentSessionId ?? photoScanStore.scanId,
                           let sessionIndex = photoScanSessions.firstIndex(where: { $0.id == sessionId }) {
                            photoScanSessions[sessionIndex].photos = newImages
                        } else if let newScanId = photoScanStore.scanId {
                            // Create new session if needed
                            currentSessionId = newScanId
                            var newSession = PhotoScanSession(scanId: newScanId)
                            newSession.photos = newImages
                            photoScanSessions.insert(newSession, at: 0)
                        }
                    }
                ),
                didHitLimit: $galleryLimitHit,
                maxTotalCount: 10
            )
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
        let photos: [UIImage]
        var productInfo: ProductInfo?
        
        var body: some View {
            if let info = productInfo {
                // === LOADED STATE ===
                HStack(spacing: 16) {
                    // Stacked Image Thumbnails (like barcode scan cards)
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white.opacity(0.1))
                            .frame(width: 68, height: 92)
                        
                        if !photos.isEmpty {
                            // Show up to three images stacked; if more exist, show a +N badge.
                            let displayedImages = Array(photos.prefix(3))
                            let remainingCount = max(photos.count - displayedImages.count, 0)
                            let stackOffset: CGFloat = 6
                            let sizeReduction: CGFloat = 4 // Each subsequent image is 4px smaller
                            
                            ZStack(alignment: .topTrailing) {
                                ZStack(alignment: .leading) {
                                    ForEach(Array(displayedImages.enumerated()), id: \.offset) { index, image in
                                        // Reverse the sizing: topmost image (highest index) should be largest
                                        let reverseIndex = displayedImages.count - 1 - index
                                        let imageWidth = 64 - CGFloat(reverseIndex) * sizeReduction
                                        let imageHeight = 88 - CGFloat(reverseIndex) * sizeReduction
                                        
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: imageWidth, height: imageHeight)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(Color.white, lineWidth: 0.4)
                                            )
                                            .shadow(radius: 4)
                                            .offset(x: CGFloat(index) * stackOffset)
                                            .zIndex(Double(index))
                                    }
                                }
                                .frame(width: 64 + CGFloat(max(displayedImages.count - 1, 0)) * stackOffset,
                                       height: 88,
                                       alignment: .leading)
                                
                                if remainingCount > 0 {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                        Text("+\(remainingCount)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.black)
                                    }
                                    .frame(width: 30, height: 30)
                                    .offset(x: 8, y: -8)
                                }
                            }
                        }
                    }
                    .padding(.leading, 16)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let brand = info.brand {
                            Text(brand)
                                .font(ManropeFont.medium.size(12))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        
                        Text(info.name ?? "Unknown Product")
                            .font(NunitoFont.semiBold.size(16))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if let netQty = info.netQuantity {
                            Text("Net Qty : \(netQty)")
                                .font(ManropeFont.regular.size(12))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        
                        Spacer().frame(height: 8)
                        
                        // Analyzing Pill
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                            
                            Text("Analyzing")
                                .font(ManropeFont.bold.size(12))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "3B9AFF"))
                        .clipShape(Capsule())
                    }
                    .padding(.vertical, 16)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.trailing, 16)
                }
                .frame(width: 300, height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                )
            } else {
                // === FETCHING STATE ===
                HStack(spacing: 16) {
                    // Icon with dashed bracket frame (for first image loading state)
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white.opacity(0.1))
                            .frame(width: 68, height: 92)
                        
                        if !photos.isEmpty {
                            // Show up to three images stacked; if more exist, show a +N badge.
                            let displayedImages = Array(photos.prefix(3))
                            let remainingCount = max(photos.count - displayedImages.count, 0)
                            let stackOffset: CGFloat = 6
                            let sizeReduction: CGFloat = 4
                            
                            ZStack(alignment: .topTrailing) {
                                ZStack(alignment: .leading) {
                                    ForEach(Array(displayedImages.enumerated()), id: \.offset) { index, image in
                                        let reverseIndex = displayedImages.count - 1 - index
                                        let imageWidth = 64 - CGFloat(reverseIndex) * sizeReduction
                                        let imageHeight = 88 - CGFloat(reverseIndex) * sizeReduction
                                        
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: imageWidth, height: imageHeight)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(Color.white, lineWidth: 0.4)
                                            )
                                            .shadow(radius: 4)
                                            .offset(x: CGFloat(index) * stackOffset)
                                            .zIndex(Double(index))
                                    }
                                }
                                .frame(width: 64 + CGFloat(max(displayedImages.count - 1, 0)) * stackOffset,
                                       height: 88,
                                       alignment: .leading)
                                
                                if remainingCount > 0 {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                        Text("+\(remainingCount)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.black)
                                    }
                                    .frame(width: 30, height: 30)
                                    .offset(x: 8, y: -8)
                                }
                            }
                        } else {
                            // First image loading state - show icon with dashed bracket frame
                            ZStack {
                                // Dashed bracket frame - square bracket style
                                ZStack {
                                    // Left bracket (vertical line with top and bottom segments)
                                    VStack(spacing: 0) {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.6))
                                            .frame(width: 2, height: 8)
                                        Spacer()
                                            .frame(height: 52)
                                        Rectangle()
                                            .fill(Color.white.opacity(0.6))
                                            .frame(width: 2, height: 8)
                                    }
                                    .frame(width: 2, height: 68)
                                    .offset(x: -30)
                                    
                                    // Right bracket (vertical line with top and bottom segments)
                                    VStack(spacing: 0) {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.6))
                                            .frame(width: 2, height: 8)
                                        Spacer()
                                            .frame(height: 52)
                                        Rectangle()
                                            .fill(Color.white.opacity(0.6))
                                            .frame(width: 2, height: 8)
                                    }
                                    .frame(width: 2, height: 68)
                                    .offset(x: 30)
                                    
                                    // Top horizontal dashed line
                                    HStack(spacing: 3) {
                                        ForEach(0..<8) { _ in
                                            Rectangle()
                                                .fill(Color.white.opacity(0.6))
                                                .frame(width: 3, height: 1.5)
                                        }
                                    }
                                    .frame(width: 60)
                                    .offset(y: -34)
                                    
                                    // Bottom horizontal dashed line
                                    HStack(spacing: 3) {
                                        ForEach(0..<8) { _ in
                                            Rectangle()
                                                .fill(Color.white.opacity(0.6))
                                                .frame(width: 3, height: 1.5)
                                        }
                                    }
                                    .frame(width: 60)
                                    .offset(y: 34)
                                }
                                
                                // Orange paper bag icon (placeholder - replace with actual asset if available)
                                Image(systemName: "bag.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color.orange)
                            }
                        }
                    }
                    .padding(.leading, 16)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Want to add more angles? Take another.")
                            .font(ManropeFont.bold.size(12))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("This helps us read small or folded text.")
                            .font(ManropeFont.regular.size(12))
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Fetching Pill - light grey with loading indicator
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.black)
                                .frame(width: 12, height: 12)
                            
                            Text("Fetching details")
                                .font(ManropeFont.bold.size(10))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.3)) // Light grey background
                        .clipShape(Capsule())
                    }
                    .padding(.vertical, 16)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.trailing, 16)
                }
                .frame(width: 300, height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                )
            }
        }
    }

    struct ProTipCard: View {
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 0) {
                    ZStack {
                        
                        Image("systemuiconscapture")
                            .resizable()
                            .frame(width: 88, height: 94)
                        
                        Image("takeawafood")
                            .resizable()
                            .frame(width: 42, height: 50)
                    }
                    .padding(.trailing, 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        (
                            Text("Pro tip — Take shots of ")
                                .font(ManropeFont.regular.size(12))
                            + Text("front")
                                .font(ManropeFont.bold.size(12))
                            + Text(", ")
                                .font(ManropeFont.regular.size(12))
                            + Text("back")
                                .font(ManropeFont.bold.size(12))
                            + Text(", and any ")
                                .font(ManropeFont.regular.size(12))
                            + Text("folded panels")
                                .font(ManropeFont.bold.size(12))
                            + Text(" for best results.")
                                .font(ManropeFont.regular.size(12))
                        )
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer(minLength: 0)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                )
                .padding(.horizontal, 38)
            }
            .buttonStyle(.plain)
        }
    }

}
