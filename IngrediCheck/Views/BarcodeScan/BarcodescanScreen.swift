import SwiftUI
import AVFoundation
import UIKit
import Combine
import PhotosUI
import CryptoKit

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
    @Environment(WebService.self) var webService
    @State private var isCaptured: Bool = false
    @State private var overlayRect: CGRect = .zero
    @State private var overlayContainerSize: CGSize = .zero
    @State private var codes: [String] = []  // Keep for barcode detection tracking
    @State private var scanIds: [String] = []  // Unified scanIds array for both modes
    @State private var scrollTargetScanId: String?
    @State private var isUserDragging: Bool = false
    @State private var lastUserDragAt: Date? = nil
    @State private var currentCenteredScanId: String? = nil
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
    @State private var selectedOverallAnalysis: String? = nil
    @State private var selectedScanId: String? = nil  // Track which scan was tapped (for local images)
    @State private var isProductDetailPresented: Bool = false
    @State private var photoFlashEnabled: Bool = false
    @State private var scanId: String? = nil  // Current active scanId for photo scans
    @State private var barcodeToScanIdMap: [String: String] = [:]  // Map barcode -> scanId for scanner mode (includes active + history)
    @State private var pendingBarcodes: Set<String> = []  // Track barcodes that are being scanned (waiting for scanId)
    @State private var historyScanIds: [String] = []  // Scan IDs from history (shown after active scans)
    @State private var scanDataCache: [String: DTO.Scan] = [:]  // Cache scan data from SSE events (barcode scans) and history
    @State private var capturedImagesPerScanId: [String: [(image: UIImage, hash: String)]] = [:]  // Track captured images per scanId with hash
    @State private var submittingScanIds: Set<String> = []  // Track scanIds currently submitting images (prevents premature getScan)
    private let skeletonCardId = "skeleton"  // Constant ID for skeleton card
    
    // MARK: - Image Hash Helper
    private func calculateImageHash(image: UIImage) -> String {
        guard let imageData = image.jpegData(compressionQuality: 1.0) else { return "" }
        return SHA256.hash(data: imageData).compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func updateToastState() {
        // When in photo mode, check for dynamic guidance from scan data
        if mode == .photo {
            // Try to get the latest_guidance from the current centered scan
            if let activeScanId = currentCenteredScanId,
               !activeScanId.isEmpty,
               activeScanId != "skeleton",
               !activeScanId.hasPrefix("pending_"),
               let scan = scanDataCache[activeScanId],
               let guidance = scan.latest_guidance,
               !guidance.isEmpty {
                // Use dynamic guidance from API
                toastState = .dynamicGuidance(guidance)
                return
            }
            
            // No dynamic guidance available, use default photo guide
            toastState = .photoGuide
            return
        }
        
        // Only show these scan-related toasts in scanner mode
        guard mode == .scanner else {
            toastState = .scanning
            return
        }
        
        // No scanIds yet: user is aligning/scanning
        guard let activeScanId = currentCenteredScanId, !activeScanId.isEmpty else {
            toastState = .scanning
            return
        }
        
        // TODO: For unified approach, we should fetch scan data and derive toast state from it
        // For now, keep basic scanning state since we're transitioning to scanIds
        toastState = .scanning
    }
    
    // MARK: - Barcode Scan
    private func startBarcodeScan(barcode: String) async {
        print("[BARCODE_SCAN] 🔵 CameraScreen: Starting barcode scan - barcode: \(barcode)")
        
        let placeholderScanId = "pending_\(barcode)"
        
        // Helper to generate ISO8601 timestamp
        let iso8601Formatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()
        
        func getCurrentTimestamp() -> String {
            return iso8601Formatter.string(from: Date())
        }
        
        do {
            try await webService.streamBarcodeScan(
                barcode: barcode,
                onProductInfo: { productInfo, scanId, productInfoSource, images in
                    // Construct DTO.Scan from SSE product_info event
                    Task { @MainActor in
                        // Remove placeholder if it exists
                        if let placeholderIndex = scanIds.firstIndex(of: placeholderScanId) {
                            scanIds.remove(at: placeholderIndex)
                        }
                        
                        // Remove skeleton card if it exists (first scan)
                        if let skeletonIndex = scanIds.firstIndex(of: skeletonCardId) {
                            scanIds.remove(at: skeletonIndex)
                        }
                        
                        // Remove from history if it's there (shouldn't happen, but just in case)
                        if let historyIndex = historyScanIds.firstIndex(of: scanId) {
                            historyScanIds.remove(at: historyIndex)
                        }
                        
                        // Construct partial DTO.Scan from product_info event
                        let partialScan = DTO.Scan(
                            id: scanId,
                            scan_type: "barcode",
                            barcode: barcode,
                            state: "analyzing",  // Analysis is in progress
                            product_info: productInfo,
                            product_info_source: productInfoSource,
                            analysis_result: nil,
                            images: images,
                            latest_guidance: nil,
                            created_at: getCurrentTimestamp(),
                            last_activity_at: getCurrentTimestamp(),
                            is_favorited: nil,
                            analysis_id: nil
                        )
                        
                        // Store in cache
                        scanDataCache[scanId] = partialScan
                        print("[BARCODE_SCAN] 💾 CameraScreen: Stored partial scan in cache - scanId: \(scanId), product_name: \(productInfo.name ?? "nil")")
                        
                        // Add real scanId at the beginning (newest first)
                        if !scanIds.contains(scanId) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                scanIds.insert(scanId, at: 0)
                                scrollTargetScanId = scanId
                            }
                            barcodeToScanIdMap[barcode] = scanId
                            pendingBarcodes.remove(barcode)
                            print("[BARCODE_SCAN] ✅ CameraScreen: scanId received - barcode: \(barcode), scanId: \(scanId), replaced placeholder/skeleton")
                        }
                        updateToastState()
                    }
                },
                onAnalysis: { analysisResult in
                    // Update existing scan in cache with analysis results
                    Task { @MainActor in
                        // Find the scanId for this barcode (should be in barcodeToScanIdMap)
                        if let scanId = barcodeToScanIdMap[barcode], let existingScan = scanDataCache[scanId] {
                            // Update scan with analysis results
                            let updatedScan = DTO.Scan(
                                id: existingScan.id,
                                scan_type: existingScan.scan_type,
                                barcode: existingScan.barcode,
                                state: "done",  // Analysis complete
                                product_info: existingScan.product_info,
                                product_info_source: existingScan.product_info_source,
                                analysis_result: analysisResult,
                                images: existingScan.images,
                                latest_guidance: existingScan.latest_guidance,
                                created_at: existingScan.created_at,
                                last_activity_at: getCurrentTimestamp(),
                                is_favorited: existingScan.is_favorited,
                                analysis_id: existingScan.analysis_id
                            )
                            
                            // Update cache
                            scanDataCache[scanId] = updatedScan
                            print("[BARCODE_SCAN] 💾 CameraScreen: Updated scan in cache with analysis - scanId: \(scanId), overall_match: \(analysisResult.overall_match ?? "nil")")
                            
                            // Trigger UI update (ScanDataCard will refresh via scanDataCache)
                            updateToastState()
                        } else {
                            print("[BARCODE_SCAN] ⚠️ CameraScreen: Received analysis but scanId not found in cache - barcode: \(barcode)")
                        }
                    }
                },
                onError: { error, scanId in
                    // Remove placeholder on error
                    Task { @MainActor in
                        if let placeholderIndex = scanIds.firstIndex(of: placeholderScanId) {
                            scanIds.remove(at: placeholderIndex)
                        }
                        // Keep skeleton card if no active scans remain
                        if scanIds.isEmpty {
                            scanIds.append(skeletonCardId)
                        }
                        pendingBarcodes.remove(barcode)
                        
                        // If scanId is available from error, add it to array
                        if let scanId = scanId {
                            // Remove skeleton if adding error scan
                            if let skeletonIndex = scanIds.firstIndex(of: skeletonCardId) {
                                scanIds.remove(at: skeletonIndex)
                            }
                            if !scanIds.contains(scanId) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    scanIds.insert(scanId, at: 0)
                                    scrollTargetScanId = scanId
                                }
                                barcodeToScanIdMap[barcode] = scanId
                            }
                        }
                        updateToastState()
                    }
                }
            )
        } catch {
            print("[BARCODE_SCAN] ❌ CameraScreen: Barcode scan failed - barcode: \(barcode), error: \(error.localizedDescription)")
            // Remove placeholder on error
            await MainActor.run {
                if let placeholderIndex = scanIds.firstIndex(of: placeholderScanId) {
                    scanIds.remove(at: placeholderIndex)
                }
                // Keep skeleton card if no active scans remain
                if scanIds.isEmpty || (scanIds.count == 1 && scanIds.first == skeletonCardId) {
                    if !scanIds.contains(skeletonCardId) {
                        scanIds.append(skeletonCardId)
                    }
                }
                pendingBarcodes.remove(barcode)
                updateToastState()
            }
        }
    }
    
    // MARK: - Scan History
    private func loadScanHistory() async {
        print("[SCAN_HISTORY] 🔵 CameraScreen: Loading scan history")
        do {
            let historyResponse = try await webService.fetchScanHistory(limit: 20, offset: 0)
            await MainActor.run {
                // Store history scans in cache to avoid API calls and prime barcode-to-scanId map
                for scan in historyResponse.scans {
                    scanDataCache[scan.id] = scan
                    
                    // If the history scan has a barcode, remember the mapping so we can reuse the card
                    if let barcode = scan.barcode, !barcode.isEmpty {
                        // Don't overwrite an active mapping – prefer the most recent active scan
                        if barcodeToScanIdMap[barcode] == nil {
                            barcodeToScanIdMap[barcode] = scan.id
                        }
                    }
                }
                print("[SCAN_HISTORY] 💾 CameraScreen: Stored \(historyResponse.scans.count) history scans in cache and updated barcodeToScanIdMap (\(barcodeToScanIdMap.count) entries)")
                
                // Extract scan IDs from history (excluding any that are already in active scans)
                let activeScanIdsSet = Set(scanIds.filter { !$0.hasPrefix("pending_") && $0 != skeletonCardId })
                let historyIds = historyResponse.scans
                    .map { $0.id }
                    .filter { !activeScanIdsSet.contains($0) }  // Don't duplicate active scans
                
                historyScanIds = historyIds
                print("[SCAN_HISTORY] ✅ CameraScreen: Loaded \(historyIds.count) history scan IDs")
            }
        } catch {
            print("[SCAN_HISTORY] ❌ CameraScreen: Failed to load scan history - error: \(error.localizedDescription)")
        }
    }
    
    // Computed property to combine active scans and history
    private var allCarouselItems: [String] {
        var items: [String] = []

        // Active scans (including pending placeholders to show "Fetching details" state)
        let activeScans = scanIds

        // Include skeleton cards from scanIds if they exist, regardless of active scans
        let skeletonCards = activeScans.filter { $0 == skeletonCardId }
        let pendingScans = activeScans.filter { $0.hasPrefix("pending_") }
        let nonSkeletonNonPendingScans = activeScans.filter { $0 != skeletonCardId && !$0.hasPrefix("pending_") }

        // Add skeleton cards first if present
        items.append(contentsOf: skeletonCards)

        // Add pending scans (showing "Fetching details" state)
        items.append(contentsOf: pendingScans)

        // Add completed active scans (newest first)
        items.append(contentsOf: nonSkeletonNonPendingScans)

        // Append history cards (excluding any that are in active scans)
        let activeScanIdsSet = Set(activeScans)
        let filteredHistory = historyScanIds.filter { !activeScanIdsSet.contains($0) }
        items.append(contentsOf: filteredHistory)

        return items
    }
    
    // MARK: - New Product Session (Photo Mode)
    private func addNewProductScanSession() {
        print("[PHOTO_SCAN] ➕ CameraScreen: Adding new product scan session")
        
        // Clear capturedImagesPerScanId for old scanId if it exists
        if let oldScanId = scanId {
            capturedImagesPerScanId[oldScanId] = nil
            print("[PHOTO_SCAN] 🗑️ CameraScreen: Cleared capturedImagesPerScanId for old scanId: \(oldScanId)")
        }
        
        // Reset scanId for new product session
        scanId = nil
        
        // Clear captured photo history for new session
        capturedPhotoHistory = []
        
        // Remove existing skeleton if it exists
        if let existingSkeletonIndex = scanIds.firstIndex(of: skeletonCardId) {
            scanIds.remove(at: existingSkeletonIndex)
        }
        
        // Add new skeleton card at the beginning (will be replaced when first image is captured)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            scanIds.insert(skeletonCardId, at: 0)
            scrollTargetScanId = skeletonCardId
        }
        
        print("[PHOTO_SCAN] ✅ CameraScreen: New product session started - skeleton card added")
    }
    
    // MARK: - Photo Image Submission
    private func submitImage(image: UIImage, scanId: String, imageIndex: Int) async {
        print("[PHOTO_SCAN] 🔵 CameraScreen: submitImage() called - scanId: \(scanId), imageIndex: \(imageIndex)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("[PHOTO_SCAN] ❌ CameraScreen: Failed to convert image to JPEG data - image_index: \(imageIndex)")
            return
        }
        
        let imageSizeKB = imageData.count / 1024
        print("[PHOTO_SCAN] 📤 CameraScreen: Submitting image - scan_id: \(scanId), image_index: \(imageIndex), image_size: \(imageSizeKB)KB")
        do {
            let response = try await webService.submitScanImage(scanId: scanId, imageData: imageData)
            print("[PHOTO_SCAN] ✅ CameraScreen: Image submitted successfully - scan_id: \(scanId), image_index: \(imageIndex), queued: \(response.queued), queue_position: \(response.queue_position)")

            // Remove from submitting set after successful submission
            // This allows ScanDataCard to start polling
            await MainActor.run {
                submittingScanIds.remove(scanId)
                print("[PHOTO_SCAN] ✅ CameraScreen: Removed scanId from submittingScanIds - scanId: \(scanId)")
            }
        } catch {
            print("[PHOTO_SCAN] ❌ CameraScreen: Failed to submit image - scan_id: \(scanId), image_index: \(imageIndex), error: \(error.localizedDescription)")

            // Remove from submitting set on error too
            await MainActor.run {
                submittingScanIds.remove(scanId)
            }
        }
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
                    
                    // Initialize with skeleton card if empty
                    if scanIds.isEmpty {
                        scanIds = [skeletonCardId]
                    }
                    
                    // Fetch scan history on appear
                    Task {
                        await loadScanHistory()
                    }
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
                    
                    // When toggling between scanner/photo, start a fresh session with a new skeleton card
                    // at the front of the carousel and scroll to it.
                    scanId = nil
                    pendingBarcodes.removeAll()
                    // Clear target first so ScanCardsCarousel's onChange(of:scrollTargetId) always fires
                    scrollTargetScanId = nil
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        scanIds = [skeletonCardId]
                    }
                    // Set scroll target on next runloop tick to ensure items are updated
                    DispatchQueue.main.async {
                        scrollTargetScanId = skeletonCardId
                    }
                    
                    updateToastState()
                    
                    // Reload history when mode changes so history cards appear to the right
                    Task {
                        await loadScanHistory()
                    }
                }
                .onChange(of: camera.isSessionRunning) { running in
                    if running {
                        camera.updateRectOfInterest(overlayRect: overlayRect, containerSize: overlayContainerSize)
                    }
                }
                .onReceive(camera.$scannedBarcode.compactMap { $0 }) { code in
                    // Check if this barcode was already scanned in the CURRENT SESSION (in scanIds)
                    // Only scroll to existing card if it's in the current session, not from history
                    if let existingScanId = barcodeToScanIdMap[code], scanIds.contains(existingScanId) {
                        // Barcode already scanned in this session - scroll to existing card
                        print("[BARCODE_SCAN] 🔄 CameraScreen: Barcode already scanned in this session - scrolling to existing card - barcode: \(code), scanId: \(existingScanId)")
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            scrollTargetScanId = existingScanId
                        }
                        updateToastState()
                        return
                    }
                    
                    // Check if this barcode is already being scanned (pending)
                    let placeholderScanId = "pending_\(code)"
                    if pendingBarcodes.contains(code) {
                        print("[BARCODE_SCAN] ⏳ CameraScreen: Barcode already being scanned - barcode: \(code)")
                        // Scroll to the pending card if it exists
                        if scanIds.contains(placeholderScanId) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                scrollTargetScanId = placeholderScanId
                            }
                        }
                        return
                    }
                    
                    // Track barcode for detection
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        if !codes.contains(code) {
                            codes.insert(code, at: 0)
                        }
                    }
                    
                    // Mark barcode as pending and immediately show skeleton card
                    pendingBarcodes.insert(code)
                    if !scanIds.contains(placeholderScanId) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            // Remove skeleton card if it's the first scan
                            if let skeletonIndex = scanIds.firstIndex(of: skeletonCardId) {
                                scanIds.remove(at: skeletonIndex)
                            }
                            
                            scanIds.insert(placeholderScanId, at: 0)
                            scrollTargetScanId = placeholderScanId
                        }
                        print("[BARCODE_SCAN] 📋 CameraScreen: Added placeholder card for barcode - barcode: \(code), placeholderScanId: \(placeholderScanId)")
                    }
                    
                    // Start barcode scan and get scanId (will replace placeholder when received)
                    Task { @MainActor in
                        await startBarcodeScan(barcode: code)
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
                // Photo mode overlay: capture guide frame
                GeometryReader { geo in
                    let centerX = geo.size.width / 2
                    let guideTop: CGFloat = 146
                    let guideSize: CGFloat = 244
                    let guideCenterY = guideTop + guideSize / 2
                    
                    // Capture guide frame
                    Image("imagecaptureUI")
                        .resizable()
                        .frame(width: guideSize, height: guideSize)
                        .position(x: centerX, y: guideCenterY)
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
                .padding(.bottom, 23)
                
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
                            print("[PHOTO_SCAN] 🔵 CameraScreen: capturePhoto button tapped")
                            camera.capturePhoto(useFlash: photoFlashEnabled) { image in
                                if let image = image {
                                    print("[PHOTO_SCAN] 📸 CameraScreen: Camera callback received - hasImage: true")
                                    
                                    // Update UI and submit image on MainActor
                                    Task { @MainActor in
                                        // Determine which scanId to use based on centered card
                                        let scanIdToUse: String
                                        let isUsingCenteredCard: Bool  // Track if we're using a centered existing card

                                        // If there's a centered card that's not skeleton/pending/empty, use that
                                        if let centeredId = currentCenteredScanId,
                                           !centeredId.isEmpty,  // Check for empty string
                                           centeredId != skeletonCardId,
                                           !centeredId.hasPrefix("pending_") {
                                            scanIdToUse = centeredId
                                            scanId = centeredId  // Update state to match
                                            isUsingCenteredCard = true
                                            print("[PHOTO_SCAN] 🎯 CameraScreen: Using centered card's scanId - scanId: \(scanIdToUse)")
                                        } else {
                                            // Generate new scanId or reuse existing one for new scan
                                            if scanId == nil {
                                                scanId = UUID().uuidString
                                                print("[PHOTO_SCAN] 🆔 CameraScreen: Generated new scan_id: \(scanId!)")
                                            } else {
                                                print("[PHOTO_SCAN] 🆔 CameraScreen: Using existing scan_id: \(scanId!)")
                                            }
                                            scanIdToUse = scanId!
                                            isUsingCenteredCard = false
                                        }
                                        
                                        // Calculate image hash
                                        let imageHash = calculateImageHash(image: image)
                                        print("[PHOTO_SCAN] 🔐 CameraScreen: Calculated image hash - hash: \(imageHash)")

                                        // Calculate image index BEFORE appending (0-based index)
                                        let imageIndex = capturedImagesPerScanId[scanIdToUse]?.count ?? 0
                                        print("[PHOTO_SCAN] 📸 CameraScreen: Photo captured - imageIndex: \(imageIndex)")

                                        // Store image and hash in capturedImagesPerScanId
                                        if capturedImagesPerScanId[scanIdToUse] == nil {
                                            capturedImagesPerScanId[scanIdToUse] = []
                                        }
                                        capturedImagesPerScanId[scanIdToUse]?.append((image: image, hash: imageHash))
                                        print("[PHOTO_SCAN] 💾 CameraScreen: Stored image in capturedImagesPerScanId - scanId: \(scanIdToUse), imageIndex: \(imageIndex), totalImages: \(capturedImagesPerScanId[scanIdToUse]?.count ?? 0)")
                                        
                                        capturedPhoto = image
                                        capturedPhotoHistory.insert(image, at: 0)
                                        if capturedPhotoHistory.count > 10 {
                                            capturedPhotoHistory.removeLast(capturedPhotoHistory.count - 10)
                                        }

                                        // Add scanId to scanIds immediately (for first photo of this product)
                                        // Subsequent photos for same scanId will just update the localImages
                                        let isFirstPhotoForThisScan = !scanIds.contains(scanIdToUse)
                                        if isFirstPhotoForThisScan {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                if let skeletonIndex = scanIds.firstIndex(of: skeletonCardId) {
                                                    // Replace skeleton with new scanId
                                                    scanIds[skeletonIndex] = scanIdToUse
                                                    // Only scroll if not using centered card (skeleton replacement always scrolls)
                                                    if !isUsingCenteredCard {
                                                        scrollTargetScanId = scanIdToUse
                                                    }
                                                } else {
                                                    // Insert at beginning (before history)
                                                    scanIds.insert(scanIdToUse, at: 0)
                                                    // Only scroll if not using centered card
                                                    if !isUsingCenteredCard {
                                                        scrollTargetScanId = scanIdToUse
                                                    }
                                                }
                                            }

                                            // Remove from history if it's there
                                            if let historyIndex = historyScanIds.firstIndex(of: scanIdToUse) {
                                                historyScanIds.remove(at: historyIndex)
                                            }

                                            if isUsingCenteredCard {
                                                print("[PHOTO_SCAN] ✅ CameraScreen: Added centered card to active scans (no scroll) - scanId: \(scanIdToUse)")
                                            } else {
                                                print("[PHOTO_SCAN] ✅ CameraScreen: Added scanId to scanIds immediately (first photo) - scanId: \(scanIdToUse)")
                                            }
                                        } else {
                                            print("[PHOTO_SCAN] 🔄 CameraScreen: Reusing existing scanId (subsequent photo) - scanId: \(scanIdToUse)")
                                        }

                                        // Mark as submitting for EVERY photo (not just first)
                                        // This ensures we re-poll after each new image is submitted
                                        // because each new photo may reveal additional product information
                                        submittingScanIds.insert(scanIdToUse)
                                        print("[PHOTO_SCAN] 📝 CameraScreen: Marked scanId as submitting - scanId: \(scanIdToUse), imageIndex: \(imageIndex)")

                                        // Submit image to scan API
                                        // After 200 response, scanId will be removed from submittingScanIds
                                        // This triggers task(id: isSubmitting) in ScanDataCard to re-fetch and re-poll
                                        print("[PHOTO_SCAN] 🚀 CameraScreen: Starting Task to submit image - scanId: \(scanIdToUse), imageIndex: \(imageIndex)")
                                        Task {
                                            await submitImage(image: image, scanId: scanIdToUse, imageIndex: imageIndex)
                                        }
                                    }
                                } else {
                                    print("[PHOTO_SCAN] ❌ CameraScreen: Camera callback returned nil image")
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
            
            // Unified carousel for both scanner and photo modes
            // Structure: [skeleton/active scans] [history scans]
            VStack {
                Spacer()
                
                ZStack(alignment: .leading) {
                    // Carousel cards
                    ScanCardsCarousel(
                        items: allCarouselItems,
                        cardContent: { itemId in
                            // Use ScanDataCard for all cases (skeleton, pending, and actual scans)
                            // ScanDataCard will detect skeleton mode based on scanId
                            let localImagesArray = capturedImagesPerScanId[itemId]?.map { $0.image }
                            let isSubmitting = submittingScanIds.contains(itemId)
                            ScanDataCard(
                                scanId: itemId,
                                initialScan: scanDataCache[itemId],  // nil for skeleton/pending/photo scans
                                isSubmitting: isSubmitting,  // Track if image is currently being submitted
                                localImages: localImagesArray,  // Pass locally captured images
                                onRetryShown: {
                                    showRetryCallout = true
                                },
                                onRetryHidden: {
                                    showRetryCallout = false
                                },
                                onResultUpdated: {
                                    // When card updates, refresh toast state
                                    updateToastState()
                                },
                                onScanUpdated: { updatedScan in
                                    // Update cache when scan data changes (e.g., from polling)
                                    // This enables toast to reflect latest_guidance changes
                                    scanDataCache[itemId] = updatedScan
                                    updateToastState()
                                },
                                onTap: { product, matchStatus, ingredientRecommendations, overallAnalysis, tappedScanId in
                                        selectedProduct = product
                                        selectedMatchStatus = matchStatus
                                        selectedIngredientRecommendations = ingredientRecommendations
                                        selectedOverallAnalysis = overallAnalysis
                                        selectedScanId = tappedScanId
                                        isProductDetailPresented = true
                                    }
                                )
                        },
                        scrollTargetId: scrollTargetScanId,
                        onCardCenterChanged: { nearestScanId in
                            currentCenteredScanId = nearestScanId
                            updateToastState()
                        },
                        cardCenterData: $cardCenterData
                    )
                    
                    // Add New Product button (photo mode only) - left side, center-aligned with carousel cards
                    if mode == .photo {
                        VStack {
                            Spacer()
                            HStack(spacing: 0) {
                                Button(action: {
                                    addNewProductScanSession()
                                }) {
                                    ZStack {
                                        // Background with blur effect
                                        // #E8E8E833 = rgba(232, 232, 232, 0.2)
                                        Rectangle()
                                            .fill(Color(hex: "#E8E8E8").opacity(0.2))
                                            .background(.ultraThinMaterial)
                                            .frame(width: 27, height: 120)
                                            .clipShape(RoundedCorner(radius: 30, corners: [.topRight, .bottomRight]))
                                        
                                        // Icon
                                        Image("addNewProductCaptures")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                    }
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                            .frame(height: 120)
                            Spacer()
                        }
                        .zIndex(10) // Ensure button is in front of carousel cards
                    }
                }
            }
            .padding(.top, 243)
            
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
            if let selectedScanId = selectedScanId {
                // Pass scanId for real-time updates
                // Get local images for this scanId (if any)
                let localImagesForScan = capturedImagesPerScanId[selectedScanId]?.map { $0.image }
                let initialScan = scanDataCache[selectedScanId]  // Get cached scan if available

                ProductDetailView(
                    scanId: selectedScanId,  // NEW: Pass scanId for real-time updates
                    initialScan: initialScan,  // NEW: Pass initial scan data
                    localImages: localImagesForScan,  // Pass local images for photo mode
                    isPlaceholderMode: false
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

