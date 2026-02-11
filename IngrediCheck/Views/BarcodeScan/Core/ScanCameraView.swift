import SwiftUI
import AVFoundation
import UIKit
import Combine
import PhotosUI
import CryptoKit
import os
import StoreKit

enum CameraPresentationSource {
    case homeView
    case productDetailView
    case pushNavigation  // Used when navigating via AppRoute (Single Root NavigationStack)
}

struct ScanCameraView: View {

    @StateObject var camera = BarcodeCameraManager()
    @State private var cameraStatus: AVAuthorizationStatus = .notDetermined
    @Environment(\.scenePhase) var scenePhase
    @Environment(WebService.self) var webService
    @Environment(ScanHistoryStore.self) var scanHistoryStore
    @Environment(UserPreferences.self) var userPreferences
    @Environment(AppState.self) var appState: AppState?  // Optional - available when in root NavigationStack
    @Environment(\.dismiss) private var dismiss
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
    @State private var completedHapticScanIds: Set<String> = []  // Track scans we've already fired haptics for

    // MARK: - Rating Prompt State
    @State private var awaitingRatingOutcome = false
    @State private var ratingPromptPresentedAt: Date?
    @State private var dismissalFallbackTask: Task<Void, Never>?

    // MARK: - Presentation Source Tracking
    @State private var presentationSource: CameraPresentationSource = .homeView
    @State private var isProgrammaticModeChange: Bool = false
    @State private var targetScanIdFromProductDetail: String? = nil
    
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

        // Check for pending placeholder (fetching details)
        if activeScanId.hasPrefix("pending_") {
            toastState = .extractionSuccess
            return
        }

        // Check for skeleton card
        if activeScanId == skeletonCardId {
            toastState = .scanning
            return
        }

        // Fetch scan data from cache and derive toast state
        guard let scan = scanDataCache[activeScanId] else {
            // No scan data available yet
            toastState = .scanning
            return
        }

        // Check scan state
        if scan.state == "analyzing" || scan.state == "processing_images" {
            toastState = .analyzing
            return
        }

        // Check if analysis is complete
        if scan.state == "done", let analysisResult = scan.analysis_result {
            // Check overall match status
            switch analysisResult.overall_match {
            case "match":
                toastState = .match
            case "not_match":
                toastState = .notMatch
            case "uncertain":
                toastState = .uncertain
            default:
                toastState = .uncertain
            }
            return
        }

        // Check if scan has error (empty product info and no analysis)
        // Error state: product_info has no name/brand/ingredients and no analysis result
        if scan.product_info.name == nil &&
           scan.product_info.brand == nil &&
           scan.product_info.ingredients.isEmpty &&
           scan.analysis_result == nil {
            toastState = .notIdentified
            return
        }

        // Default to scanning
        toastState = .scanning
    }
    
    // MARK: - Barcode Scan
    private func startBarcodeScan(barcode: String) async {
        Log.debug("BARCODE_SCAN", "🔵 CameraScreen: Starting barcode scan - barcode: \(barcode)")
        
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
                        
                        // Store in cache AND store
                        scanDataCache[scanId] = partialScan
                        scanHistoryStore.upsertScan(partialScan)
                        Log.debug("BARCODE_SCAN", "💾 CameraScreen: Stored partial scan in cache and store - scanId: \(scanId), product_name: \(productInfo.name ?? "nil")")
                        
                        // Add real scanId at the beginning (newest first)
                        if !scanIds.contains(scanId) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                scanIds.insert(scanId, at: 0)
                                scrollTargetScanId = scanId
                            }
                            barcodeToScanIdMap[barcode] = scanId
                            pendingBarcodes.remove(barcode)
                            Log.debug("BARCODE_SCAN", "✅ CameraScreen: scanId received - barcode: \(barcode), scanId: \(scanId), replaced placeholder/skeleton")
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
                            
                            // Update cache AND store
                            scanDataCache[scanId] = updatedScan
                            scanHistoryStore.upsertScan(updatedScan)
                            Log.debug("BARCODE_SCAN", "💾 CameraScreen: Updated scan in cache and store with analysis - scanId: \(scanId), overall_match: \(analysisResult.overall_match ?? "nil")")
                            
                            // Trigger UI update (ScanDataCard will refresh via scanDataCache)
                            updateToastState()
                        } else {
                            Log.warning("BARCODE_SCAN", "⚠️ CameraScreen: Received analysis but scanId not found in cache - barcode: \(barcode)")
                        }
                    }
                },
                onError: { error, scanId in
                    // Remove placeholder on error
                    Task { @MainActor in
                        Log.error("BARCODE_SCAN", "❌ CameraScreen: Barcode scan error - barcode: \(barcode), error: \(error.localizedDescription), scanId: \(scanId ?? "nil")")

                        if let placeholderIndex = scanIds.firstIndex(of: placeholderScanId) {
                            scanIds.remove(at: placeholderIndex)
                        }
                        pendingBarcodes.remove(barcode)

                        // If scanId is available from error, store error state in cache and add to array
                        if let scanId = scanId {
                            // Create empty product info for error state
                            let emptyProductInfo = DTO.ScanProductInfo(
                                name: nil,
                                brand: nil,
                                ingredients: [],
                                images: nil
                            )

                            // Create error scan with minimal data to show error state
                            let errorScan = DTO.Scan(
                                id: scanId,
                                scan_type: "barcode",
                                barcode: barcode,
                                state: "done",  // Mark as done but with no results (indicates error)
                                product_info: emptyProductInfo,  // Empty product info = error state
                                product_info_source: nil,
                                analysis_result: nil,  // No analysis = error state
                                images: [],  // Empty images array
                                latest_guidance: nil,
                                created_at: getCurrentTimestamp(),
                                last_activity_at: getCurrentTimestamp(),
                                is_favorited: nil,
                                analysis_id: nil
                            )

                            // Store error scan in cache AND store
                            scanDataCache[scanId] = errorScan
                            scanHistoryStore.upsertScan(errorScan)
                            Log.debug("BARCODE_SCAN", "💾 CameraScreen: Stored error scan in cache and store - scanId: \(scanId)")

                            // Remove skeleton if adding error scan
                            if let skeletonIndex = scanIds.firstIndex(of: skeletonCardId) {
                                scanIds.remove(at: skeletonIndex)
                            }

                            // Add error scanId to array
                            if !scanIds.contains(scanId) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    scanIds.insert(scanId, at: 0)
                                    scrollTargetScanId = scanId
                                }
                                barcodeToScanIdMap[barcode] = scanId
                                Log.debug("BARCODE_SCAN", "✅ CameraScreen: Added error scanId to scanIds - scanId: \(scanId)")
                            }
                        } else {
                            // No scanId from error - keep skeleton card if no active scans remain
                            if scanIds.isEmpty {
                                scanIds.append(skeletonCardId)
                            }
                        }

                        updateToastState()
                    }
                }
            )
        } catch {
            Log.error("BARCODE_SCAN", "❌ CameraScreen: Barcode scan failed - barcode: \(barcode), error: \(error.localizedDescription)")
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
    
    // MARK: - Haptics
    private func triggerAnalysisCompletedHaptic(for scanId: String) {
        // Ensure we only fire once per scan
        guard !completedHapticScanIds.contains(scanId) else { return }
        completedHapticScanIds.insert(scanId)

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    // MARK: - Rating Prompt
    private func checkAndPromptForRating() {
        if userPreferences.canPromptForRating() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                userPreferences.recordRatingPrompt()
                ratingPromptPresentedAt = Date()
                awaitingRatingOutcome = true
                scheduleDismissalFallback()

                let foregroundScene = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first { $0.activationState == .foregroundActive }
                if let windowScene = foregroundScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
            }
        }
    }

    private func scheduleDismissalFallback() {
        dismissalFallbackTask?.cancel()
        dismissalFallbackTask = Task {
            try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
            await MainActor.run {
                guard awaitingRatingOutcome else { return }
                guard scenePhase == .active else { return }
                handleRatingPromptFinished(recordDismissal: true)
            }
        }
    }

    private func handleRatingPromptFinished(recordDismissal: Bool) {
        dismissalFallbackTask?.cancel()
        dismissalFallbackTask = nil
        defer {
            awaitingRatingOutcome = false
            ratingPromptPresentedAt = nil
        }
        if recordDismissal {
            userPreferences.recordPromptDismissal()
        }
    }

    private func handleRatingScenePhaseChange(_ newPhase: ScenePhase) {
        guard awaitingRatingOutcome else { return }
        switch newPhase {
        case .active:
            if let start = ratingPromptPresentedAt {
                let elapsed = Date().timeIntervalSince(start)
                if elapsed < 5.0 {
                    handleRatingPromptFinished(recordDismissal: true)
                } else {
                    handleRatingPromptFinished(recordDismissal: false)
                }
            } else {
                handleRatingPromptFinished(recordDismissal: true)
            }
        case .background:
            handleRatingPromptFinished(recordDismissal: false)
        default:
            break
        }
    }

    // MARK: - Scan History
    private func loadScanHistory() async {
        Log.debug("SCAN_HISTORY", "🔵 CameraScreen: Loading scan history from store")

        // If store is currently loading, wait for it to complete
        // If store already has data (loaded by HomeView), skip the API call
        if scanHistoryStore.isLoading {
            Log.debug("SCAN_HISTORY", "⏳ CameraScreen: Store is loading, waiting...")
            // Wait for loading to complete (poll with short delay)
            while scanHistoryStore.isLoading {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            }
            Log.debug("SCAN_HISTORY", "✅ CameraScreen: Store finished loading")
        } else if scanHistoryStore.scans.isEmpty {
            // Only load from API if store has no data
            await scanHistoryStore.loadHistory(limit: 20, offset: 0)
        } else {
            Log.debug("SCAN_HISTORY", "📦 CameraScreen: Using existing store data (\(scanHistoryStore.scans.count) scans)")
        }

        await syncHistoryFromStore()
    }
    
    /// Syncs local state with data from ScanHistoryStore
    private func syncHistoryFromStore() async {
        await MainActor.run {
            // Sync store data to local cache for immediate access
            for scan in scanHistoryStore.scans {
                scanDataCache[scan.id] = scan
            }

            // Use store's barcode mapping
            barcodeToScanIdMap = scanHistoryStore.barcodeToScanIdMap

            // Extract scan IDs from store history (excluding any that are already in active scans)
            let activeScanIdsSet = Set(scanIds.filter { !$0.hasPrefix("pending_") && $0 != skeletonCardId })
            let historyIds = scanHistoryStore.scans
                .map { $0.id }
                .filter { !activeScanIdsSet.contains($0) }  // Don't duplicate active scans

            historyScanIds = historyIds
            Log.debug("SCAN_HISTORY", "✅ CameraScreen: Synced \(historyIds.count) history scan IDs from store")
        }
    }
    
    /// Handles initial scroll to scanId when opened from ProductDetailView
    /// Does NOT move the scanId from its original position - just scrolls to it
    private func handleInitialScrollToScanId(_ targetId: String) async {
        await MainActor.run {
            Log.debug("SCAN_SCROLL", "🔵 CameraScreen: Handling initial scroll to scanId: \(targetId)")
            
            // Update scanId state to match target (for photo capture association)
            scanId = targetId
            
            // Wait for the carousel items to update and ensure targetId is in allCarouselItems
            // Use a polling approach to wait for the item to appear in the carousel
            Task { @MainActor in
                var attempts = 0
                let maxAttempts = 20  // Wait up to 2 seconds (20 * 0.1s)
                
                while attempts < maxAttempts {
                    // Check if targetId is in allCarouselItems
                    if allCarouselItems.contains(targetId) {
                        Log.debug("SCAN_SCROLL", "✅ CameraScreen: Target scanId found in carousel items, scrolling...")

                        // Wait for layout to settle before scrolling
                        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

                        // Clear scrollTargetScanId first to ensure onChange fires
                        scrollTargetScanId = nil

                        // Wait a frame to ensure the clear is processed
                        try? await Task.sleep(nanoseconds: 50_000_000)  // ~3 frames at 60fps

                        // Now set it to trigger the scroll
                        scrollTargetScanId = targetId
                        Log.debug("SCAN_SCROLL", "✅ CameraScreen: Set scrollTargetScanId to: \(targetId)")
                        return
                    }
                    
                    // Wait a bit before checking again
                    try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
                    attempts += 1
                }
                
                // Fallback: set it anyway after max attempts
                Log.warning("SCAN_SCROLL", "⚠️ CameraScreen: Target scanId not found in carousel after \(maxAttempts) attempts, setting scroll target anyway")
                scrollTargetScanId = nil
                try? await Task.sleep(nanoseconds: 16_666_666)
                scrollTargetScanId = targetId
            }
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
        Log.debug("PHOTO_SCAN", "➕ CameraScreen: Adding new product scan session")

        // Clear capturedImagesPerScanId for old scanId if it exists
        if let oldScanId = scanId {
            capturedImagesPerScanId[oldScanId] = nil
            Log.debug("PHOTO_SCAN", "🗑️ CameraScreen: Cleared capturedImagesPerScanId for old scanId: \(oldScanId)")
        }

        // Reset scanId for new product session
        scanId = nil

        // Clear captured photo history for new session
        capturedPhotoHistory = []

        // Remove existing skeleton if it exists
        if let existingSkeletonIndex = scanIds.firstIndex(of: skeletonCardId) {
            scanIds.remove(at: existingSkeletonIndex)
        }

        // Clear scroll target first so carousel's onChange always fires
        scrollTargetScanId = nil

        // Add new skeleton card at the beginning (will be replaced when first image is captured)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            scanIds.insert(skeletonCardId, at: 0)
        }

        // Set scroll target on next runloop tick to ensure items are updated
        DispatchQueue.main.async {
            scrollTargetScanId = skeletonCardId
        }

        Log.debug("PHOTO_SCAN", "✅ CameraScreen: New product session started - skeleton card added")
    }
    
    // MARK: - Photo Image Submission
    private func submitImage(image: UIImage, scanId: String, imageIndex: Int) async {
        Log.debug("PHOTO_SCAN", "🔵 CameraScreen: submitImage() called - scanId: \(scanId), imageIndex: \(imageIndex)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            Log.error("PHOTO_SCAN", "❌ CameraScreen: Failed to convert image to JPEG data - image_index: \(imageIndex)")
            return
        }
        
        let imageSizeKB = imageData.count / 1024
        Log.debug("PHOTO_SCAN", "📤 CameraScreen: Submitting image - scan_id: \(scanId), image_index: \(imageIndex), image_size: \(imageSizeKB)KB")
        do {
            let response = try await webService.submitScanImage(scanId: scanId, imageData: imageData)
            Log.debug("PHOTO_SCAN", "✅ CameraScreen: Image submitted successfully - scan_id: \(scanId), image_index: \(imageIndex), queued: \(response.queued), queue_position: \(response.queue_position)")

            // Remove from submitting set after successful submission
            // This allows ScanDataCard to start polling
            await MainActor.run {
                submittingScanIds.remove(scanId)
                Log.debug("PHOTO_SCAN", "✅ CameraScreen: Removed scanId from submittingScanIds - scanId: \(scanId)")
            }
        } catch {
            Log.error("PHOTO_SCAN", "❌ CameraScreen: Failed to submit image - scan_id: \(scanId), image_index: \(imageIndex), error: \(error.localizedDescription)")

            // Remove from submitting set on error too
            await MainActor.run {
                submittingScanIds.remove(scanId)
            }
        }
    }
    
    // MARK: - Photo Processing
    /// Processes a photo image (from camera or gallery) through the complete flow:
    /// scanId determination, hash calculation, storage, UI updates, and API submission
    private func processPhoto(image: UIImage) async {
        Log.debug("PHOTO_SCAN", "📸 CameraScreen: processPhoto() called")
        
        // Determine which scanId to use based on centered card
        let (scanIdToUse, isUsingCenteredCard) = await MainActor.run { () -> (String, Bool) in
            // If there's a centered card that's not skeleton/pending/empty, use that
            if let centeredId = currentCenteredScanId,
               !centeredId.isEmpty,
               centeredId != skeletonCardId,
               !centeredId.hasPrefix("pending_") {
                scanId = centeredId  // Update state to match
                Log.debug("PHOTO_SCAN", "🎯 CameraScreen: Using centered card's scanId - scanId: \(centeredId)")
                return (centeredId, true)
            } else {
                // Generate new scanId or reuse existing one for new scan
                if scanId == nil {
                    scanId = UUID().uuidString
                    Log.debug("PHOTO_SCAN", "🆔 CameraScreen: Generated new scan_id: \(scanId!)")
                } else {
                    Log.debug("PHOTO_SCAN", "🆔 CameraScreen: Using existing scan_id: \(scanId!)")
                }
                return (scanId!, false)
            }
        }
        
        // Calculate image hash
        let imageHash = calculateImageHash(image: image)
        Log.debug("PHOTO_SCAN", "🔐 CameraScreen: Calculated image hash - hash: \(imageHash)")
        
        // Calculate image index and store image
        let imageIndex = await MainActor.run { () -> Int in
            // Calculate image index BEFORE appending (0-based index)
            let imageIndex = capturedImagesPerScanId[scanIdToUse]?.count ?? 0
            Log.debug("PHOTO_SCAN", "📸 CameraScreen: Photo processed - imageIndex: \(imageIndex)")
            
            // Store image and hash in capturedImagesPerScanId
            if capturedImagesPerScanId[scanIdToUse] == nil {
                capturedImagesPerScanId[scanIdToUse] = []
            }
            capturedImagesPerScanId[scanIdToUse]?.append((image: image, hash: imageHash))
            Log.debug("PHOTO_SCAN", "💾 CameraScreen: Stored image in capturedImagesPerScanId - scanId: \(scanIdToUse), imageIndex: \(imageIndex), totalImages: \(capturedImagesPerScanId[scanIdToUse]?.count ?? 0)")
            
            // Add to capturedPhotoHistory (limit to 10)
            capturedPhoto = image
            capturedPhotoHistory.insert(image, at: 0)
            if capturedPhotoHistory.count > 10 {
                capturedPhotoHistory.removeLast(capturedPhotoHistory.count - 10)
            }
            
            // Add scanId to scanIds immediately (for first photo of this product)
            // Subsequent photos for same scanId will just update the localImages
            let isInActiveScanIds = scanIds.contains(scanIdToUse)
            let isInHistoryScanIds = historyScanIds.contains(scanIdToUse)
            let isFirstPhotoForThisScan = !isInActiveScanIds && !isInHistoryScanIds

            if isFirstPhotoForThisScan {
                // Truly new scan - add to carousel
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
                    Log.debug("PHOTO_SCAN", "✅ CameraScreen: Added centered card to active scans (no scroll) - scanId: \(scanIdToUse)")
                } else {
                    Log.debug("PHOTO_SCAN", "✅ CameraScreen: Added scanId to scanIds immediately (first photo) - scanId: \(scanIdToUse)")
                }
            } else if isInHistoryScanIds {
                // Adding photo to existing history scan - keep it in place
                Log.debug("PHOTO_SCAN", "🔄 CameraScreen: Adding photo to history scan (keeping position) - scanId: \(scanIdToUse)")
            } else {
                Log.debug("PHOTO_SCAN", "🔄 CameraScreen: Reusing existing active scanId (subsequent photo) - scanId: \(scanIdToUse)")
            }
            
            // Mark as submitting for EVERY photo (not just first)
            // This ensures we re-poll after each new image is submitted
            // because each new photo may reveal additional product information
            submittingScanIds.insert(scanIdToUse)
            Log.debug("PHOTO_SCAN", "📝 CameraScreen: Marked scanId as submitting - scanId: \(scanIdToUse), imageIndex: \(imageIndex)")
            
            return imageIndex
        }
        
        // Submit image to scan API
        // After 200 response, scanId will be removed from submittingScanIds
        // This triggers task(id: isSubmitting) in ScanDataCard to re-fetch and re-poll
        Log.debug("PHOTO_SCAN", "🚀 CameraScreen: Starting Task to submit image - scanId: \(scanIdToUse), imageIndex: \(imageIndex)")
        await submitImage(image: image, scanId: scanIdToUse, imageIndex: imageIndex)
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
                        
                        // If opened with initial scroll target (from ProductDetailView or push navigation), handle scrolling
                        // This handles the case when view is opened to add more photos to an existing scan
                        if presentationSource == .productDetailView || presentationSource == .pushNavigation {
                            // Check if we have an initial scroll target from the initializer
                            // Store it before it might get cleared
                            let initialTarget = scrollTargetScanId
                            if let target = initialTarget, !target.isEmpty, target != skeletonCardId {
                                Log.debug("SCAN_SCROLL", "🔵 CameraScreen: onAppear - Found initial scroll target: \(target)")
                                await handleInitialScrollToScanId(target)
                            }
                        }
                    }
                }
                .onDisappear { camera.stopSession() }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        if cameraStatus == .authorized { camera.startSession() }
                    } else if newPhase == .background {
                        camera.stopSession()
                    }
                    handleRatingScenePhaseChange(newPhase)
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
                    
                    // Only reset scan state when:
                    // 1. Opened from HomeView (presentationSource == .homeView), OR
                    // 2. Manual toggle (isProgrammaticModeChange == false)
                    // Do NOT reset when:
                    // - Programmatically returning from ProductDetailView
                    // - Opened with initial scroll target (adding photos to existing scan)
                    let hasInitialScrollTarget = scrollTargetScanId != nil && scrollTargetScanId != skeletonCardId
                    let shouldReset = (presentationSource == .homeView || !isProgrammaticModeChange) && !hasInitialScrollTarget

                    if shouldReset {
                        // When toggling between scanner/photo from HomeView or manual toggle, start a fresh session
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
                    } else if isProgrammaticModeChange, let targetId = targetScanIdFromProductDetail {
                        // Returning from ProductDetailView - preserve state and scroll to target
                        // Use the helper function to handle scrolling
                        Task {
                            await handleInitialScrollToScanId(targetId)
                        }
                    }
                    
                    // Reset flags after handling
                    isProgrammaticModeChange = false
                    targetScanIdFromProductDetail = nil
                    
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
                        Log.debug("BARCODE_SCAN", "🔄 CameraScreen: Barcode already scanned in this session - scrolling to existing card - barcode: \(code), scanId: \(existingScanId)")
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            scrollTargetScanId = existingScanId
                        }
                        updateToastState()
                        return
                    }
                    
                    // Check if this barcode is already being scanned (pending)
                    let placeholderScanId = "pending_\(code)"
                    if pendingBarcodes.contains(code) {
                        Log.debug("BARCODE_SCAN", "⏳ CameraScreen: Barcode already being scanned - barcode: \(code)")
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
                        Log.debug("BARCODE_SCAN", "📋 CameraScreen: Added placeholder card for barcode - barcode: \(code), placeholderScanId: \(placeholderScanId)")
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
                .onAppear {
                    // Check if we need to scroll to a specific card (coming back from ProductDetail)
                    if let targetId = appState?.scrollToScanId, !targetId.isEmpty {
                        Log.debug("SCAN_SCROLL", "🔵 CameraScreen: onAppear - scrollToScanId from AppState: \(targetId)")
                        scrollTargetScanId = targetId
                        // Clear the scroll target after using it
                        appState?.scrollToScanId = nil
                    }
                }

            if mode == .scanner {
                BarcodeScannerOverlay(onRectChange: { rect, size in
                    overlayRect = rect
                    overlayContainerSize = size
                    camera.updateRectOfInterest(overlayRect: rect, containerSize: size)
                })
                .environmentObject(camera)
            } else {
                // Photo mode overlay: capture guide frame
                GeometryReader { geo in
                    let centerX = geo.size.width / 2
                    let guideTop: CGFloat = 126
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
                ScanStatusToast(state: toastState)
                    .padding(.top, 40) // Account for navigation bar space
                    .onAppear {
                        updateToastState()
                    }
                Spacer()
                if mode == .photo {
                    HStack {
                        FlashToggleButton(
                            isScannerMode: false,
                            onTogglePhotoFlash: { enabled in
                                photoFlashEnabled = enabled
                            }
                        )
                        
                        Spacer()
                        
                        // MARK: - Image Capturing Button
                        // Center: Capture photo button - captures a photo from the camera and adds it to the photo history
                        Button(action: {
                            Log.debug("PHOTO_SCAN", "🔵 CameraScreen: capturePhoto button tapped")
                            camera.capturePhoto(useFlash: photoFlashEnabled) { image in
                                if let image = image {
                                    Log.debug("PHOTO_SCAN", "📸 CameraScreen: Camera callback received - hasImage: true")
                                    
                                    // Process photo through the same flow as gallery selection
                                        Task {
                                        await processPhoto(image: image)
                                    }
                                } else {
                                    Log.error("PHOTO_SCAN", "❌ CameraScreen: Camera callback returned nil image")
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
                            let localImagesArray = capturedImagesPerScanId[itemId]
                            let isSubmitting = submittingScanIds.contains(itemId)
                            ScanDataCard(
                                scanId: itemId,
                                initialScan: scanDataCache[itemId],  // nil for skeleton/pending/photo scans
                                isSubmitting: isSubmitting,  // Track if image is currently being submitted
                                localImages: localImagesArray,  // Pass locally captured images
                                cameraModeType: mode == .photo ? "photo" : "barcode",  // Pass current camera mode for skeleton/pending states
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

                                    // Trigger haptic feedback and rating prompt once when analysis is completed
                                    if updatedScan.state == "done", updatedScan.analysis_result != nil {
                                        triggerAnalysisCompletedHaptic(for: updatedScan.id)
                                        checkAndPromptForRating()
                                    }

                                    updateToastState()
                                },
                                onFavoriteToggle: { scanId, isFavorited in
                                    // Toggle favorite status via API
                                    Task {
                                        do {
                                            // Use new toggleFavorite API which returns actual state
                                            let newFavoriteState = try await webService.toggleFavorite(scanId: scanId)
                                            Log.debug("FAVORITE", "✅ Toggled favorite - scanId: \(scanId), is_favorited: \(newFavoriteState)")

                                            // Update cache with new favorite status from API response
                                            if let cachedScan = scanDataCache[scanId] {
                                                // Create updated scan with new favorite status
                                                let updatedScan = DTO.Scan(
                                                    id: cachedScan.id,
                                                    scan_type: cachedScan.scan_type,
                                                    barcode: cachedScan.barcode,
                                                    state: cachedScan.state,
                                                    product_info: cachedScan.product_info,
                                                    product_info_source: cachedScan.product_info_source,
                                                    analysis_result: cachedScan.analysis_result,
                                                    images: cachedScan.images,
                                                    latest_guidance: cachedScan.latest_guidance,
                                                    created_at: cachedScan.created_at,
                                                    last_activity_at: cachedScan.last_activity_at,
                                                    is_favorited: newFavoriteState,
                                                    analysis_id: cachedScan.analysis_id
                                                )

                                                // Update cache AND store
                                                await MainActor.run {
                                                    scanDataCache[scanId] = updatedScan
                                                    scanHistoryStore.updateFavoriteStatus(scanId: scanId, isFavorited: newFavoriteState)
                                                }
                                            }
                                        } catch {
                                            Log.error("FAVORITE", "❌ Failed to toggle favorite - scanId: \(scanId), error: \(error.localizedDescription)")
                                        }
                                    }
                                },
                                onTap: { product, matchStatus, ingredientRecommendations, overallAnalysis, tappedScanId in
                                        selectedProduct = product
                                        selectedMatchStatus = matchStatus
                                        selectedIngredientRecommendations = ingredientRecommendations
                                        selectedOverallAnalysis = overallAnalysis
                                        selectedScanId = tappedScanId

                                        // Use push navigation ONLY when opened via AppRoute (pushNavigation)
                                        // Fall back to fullScreenCover when in sheet/cover context
                                        if presentationSource == .pushNavigation, let appState = appState {
                                            let initialScan = scanDataCache[tappedScanId]
                                            appState.navigate(to: .productDetail(scanId: tappedScanId, initialScan: initialScan))
                                        } else {
                                            isProductDetailPresented = true
                                        }
                                    }
                                )
                        },
                        scrollTargetId: scrollTargetScanId,
                        onCardCenterChanged: { nearestScanId in
                            currentCenteredScanId = nearestScanId
                            updateToastState()
                            
                            // Check for pagination trigger
                            if let nearestScanId,
                               let index = allCarouselItems.firstIndex(of: nearestScanId),
                               index >= allCarouselItems.count - 3 {
                                Task {
                                    if scanHistoryStore.hasMore && !scanHistoryStore.isLoading {
                                        Log.debug("SCAN_HISTORY", "🔄 CameraScreen: Reached end of carousel, loading more history...")
                                        await scanHistoryStore.loadMore()
                                        await syncHistoryFromStore()
                                    }
                                }
                            }
                        },
                        cardCenterData: $cardCenterData
                    )
                    
                    // Add New Product button (photo mode only) - left side, center-aligned with carousel cards
                    // Hide when skeleton card is already present (no need to add another)
                    if mode == .photo && !scanIds.contains(skeletonCardId) {
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
            .padding(.top, 203)
            
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
                        
                        CaptureYourProductSheet {
                            withAnimation(.easeInOut) {
                                isShowingPhotoModeGuide = false
                            }
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: isShowingPhotoModeGuide)
                .zIndex(3)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .sheet(isPresented: $isShowingPhotoPicker) {
            PhotoPicker(images: $capturedPhotoHistory,
                        didHitLimit: $galleryLimitHit,
                        maxTotalCount: 10,
                        onImageSelected: { image in
                            await processPhoto(image: image)
                        })
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if mode == .scanner {
                    FlashToggleButton(isScannerMode: true)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Track that camera is in navigation stack (for ProductDetail "Add Photo" navigation)
            appState?.hasCameraInStack = true
            // Track that camera is currently visible (for AIBot FAB visibility)
            appState?.isInScanCameraView = true
        }
        .onDisappear {
            // Camera is being removed from navigation stack
            appState?.hasCameraInStack = false
            // Camera is no longer visible
            appState?.isInScanCameraView = false
        }
    }
}

// MARK: - ScanCameraView with Initial State

/// Wrapper for ScanCameraView that accepts initial mode and scanId
struct ScanCameraViewWithInitialState: View {
    let initialScanId: String?
    let initialMode: CameraMode
    let presentationSource: CameraPresentationSource

    var body: some View {
        ScanCameraViewInternal(
            initialScanId: initialScanId,
            initialMode: initialMode,
            presentationSource: presentationSource
        )
    }
}

/// Internal view that accepts initial state parameters
private struct ScanCameraViewInternal: View {
    let initialScanId: String?
    let initialMode: CameraMode
    let presentationSource: CameraPresentationSource

    var body: some View {
        ScanCameraView(
            initialMode: initialMode,
            initialScrollTarget: initialScanId,
            presentationSource: presentationSource
        )
    }
}

extension ScanCameraView {

    // MARK: - Initializer with initial state

    init(initialMode: CameraMode? = nil, initialScrollTarget: String? = nil, presentationSource: CameraPresentationSource = .homeView) {
        // Set initial mode if provided
        if let initialMode = initialMode {
            self._mode = State(initialValue: initialMode)
        }

        // Set initial scroll target if provided
        if let initialScrollTarget = initialScrollTarget {
            self._scrollTargetScanId = State(initialValue: initialScrollTarget)
        }
        
        // Set presentation source
        self._presentationSource = State(initialValue: presentationSource)
    }


    // MARK: - Photo Picker for gallery selection
    
    struct PhotoPicker: UIViewControllerRepresentable {
        
        @Environment(\.presentationMode) var presentationMode
        @Binding var images: [UIImage]
        @Binding var didHitLimit: Bool
        var maxTotalCount: Int = 10
        var onImageSelected: ((UIImage) async -> Void)? = nil
        
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
                
                // Process images sequentially to maintain scanId consistency
                Task {
                    for result in results {
                        let provider = result.itemProvider
                        guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                        
                        // Load image asynchronously
                        if let uiImage = try? await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<UIImage, Error>) in
                            provider.loadObject(ofClass: UIImage.self) { object, error in
                                if let error = error {
                                    continuation.resume(throwing: error)
                                } else if let uiImage = object as? UIImage {
                                    continuation.resume(returning: uiImage)
                                } else {
                                    continuation.resume(throwing: NSError(domain: "PhotoPicker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"]))
                                }
                            }
                        }) {
                            // Process image through the same flow as captured photos
                            if let processImage = parent.onImageSelected {
                                await processImage(uiImage)
                            } else {
                                // Fallback: add to history if no processor provided
                                await MainActor.run {
                                    if self.parent.images.count < self.parent.maxTotalCount {
                                        self.parent.images.insert(uiImage, at: 0)
                                    } else {
                                        self.parent.didHitLimit = true
                                    }
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
}

