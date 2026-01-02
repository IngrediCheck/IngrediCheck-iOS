import SwiftUI

/// Unified card component that displays scan data for both barcode and photo scans
/// Takes a scanId and optionally initialScan data (from SSE events or cache)
/// If initialScan is provided, uses it directly (no API call, no polling) - for barcode scans
/// If initialScan is nil, fetches via getScan and polls if needed - for photo scans
struct ScanDataCard: View {
    let scanId: String
    var initialScan: DTO.Scan? = nil  // Optional initial scan data (from SSE or cache)
    var isSubmitting: Bool = false  // If true, image is being submitted to API (prevents premature getScan)
    var localImages: [UIImage]? = nil  // Locally captured images (shown before API response)
    var onRetryShown: (() -> Void)? = nil
    var onRetryHidden: (() -> Void)? = nil
    var onResultUpdated: (() -> Void)? = nil
    var onScanUpdated: ((DTO.Scan) -> Void)? = nil  // NEW: Called when scan data updates (for cache sync)
    var onTap: ((DTO.Product, DTO.ProductRecommendation?, [DTO.IngredientRecommendation]?, String?, String) -> Void)? = nil  // Added scanId parameter

    @Environment(WebService.self) private var webService
    @Environment(AppState.self) private var appState
    @Environment(UserPreferences.self) private var userPreferences

    @State private var scan: DTO.Scan?
    @State private var cachedInitialScan: DTO.Scan?  // Store initialScan as state to watch for changes
    @State private var isLoading = false
    @State private var isPolling = false
    @State private var errorState: String?
    @State private var pollingTask: Task<Void, Never>?
    
    private var product: DTO.Product? {
        scan?.toProduct()
    }
    
    private var matchStatus: DTO.ProductRecommendation? {
        scan?.toProductRecommendation()
    }
    
    private var ingredientRecommendations: [DTO.IngredientRecommendation]? {
        scan?.analysis_result?.toIngredientRecommendations()
    }
    
    private var overallAnalysis: String? {
        scan?.analysis_result?.overall_analysis
    }
    
    private var isAnalyzing: Bool {
        // Show analyzing if:
        // 1. Scan state indicates processing/analyzing, OR
        // 2. Currently polling for updates (e.g., 2nd photo being processed)
        (scan?.state == "analyzing" || scan?.state == "processing_images") || isPolling
    }
    
    private var notFoundState: Bool {
        scan?.product_info.name == nil && scan?.product_info.brand == nil && scan?.product_info.ingredients.isEmpty == true
    }
    
    // Skeleton mode: show redacted placeholders when scanId is "skeleton" (initial empty state)
    private var isSkeletonMode: Bool {
        scanId == "skeleton"
    }
    
    // Pending mode: show "Fetching details" loading state for pending scans
    private var isPendingMode: Bool {
        scanId.hasPrefix("pending_")
    }
    
    // Determine scan type for placeholder image (barcode vs photo)
    private var scanType: String {
        scan?.scan_type ?? "barcode"  // Default to barcode if unknown
    }
    
    // Computed property to determine which images to display
    // API images (inventory/product catalog images) take priority over local user-uploaded images
    private var imagesToDisplay: (apiImages: [DTO.ImageLocationInfo]?, localImages: [UIImage]?) {
        // If API response has images (inventory images from product catalog), use them
        if let product = product, !product.images.isEmpty {
            return (apiImages: product.images, localImages: nil)
        }

        // If no API images yet, but local user-uploaded images exist, show them
        if let localImages = localImages, !localImages.isEmpty {
            return (apiImages: nil, localImages: localImages)
        }

        // No images available
        return (apiImages: nil, localImages: nil)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Left-side visual: product images or placeholder
            ZStack {
                let images = imagesToDisplay

                if isSkeletonMode {
                    // Skeleton mode: show empty state placeholder image
                    let placeholderImage = scanType == "photo" ? "PhotoScanEmptyState" : "Barcodelinecorners"
                    Image(placeholderImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 88)
                        .clipped()
                } else if isPendingMode || (isLoading && scan == nil) {
                    // Loading state: show placeholder
                    ProgressView()
                        .tint(.white.opacity(0.6))
                } else if let apiImages = images.apiImages, !apiImages.isEmpty {
                    // API images available: use them (priority)
                    let displayedImages = Array(apiImages.prefix(3))
                    let remainingCount = max(apiImages.count - displayedImages.count, 0)
                    let stackOffset: CGFloat = 6
                    let sizeReduction: CGFloat = 4

                    ZStack(alignment: .topTrailing) {
                        ZStack(alignment: .leading) {
                            ForEach(Array(displayedImages.enumerated()), id: \.offset) { index, location in
                                let reverseIndex = displayedImages.count - 1 - index
                                let imageWidth = 68 - CGFloat(reverseIndex) * sizeReduction
                                let imageHeight = 92 - CGFloat(reverseIndex) * sizeReduction

                                ScanProductImageThumbnail(imageLocation: location, isAnalyzing: isAnalyzing)
                                    .frame(width: imageWidth, height: imageHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white, lineWidth: 0.4)
                                    )
                                    .shadow(radius: 4)
                                    .offset(x: CGFloat(index) * stackOffset)
                                    .zIndex(Double(index))
                            }
                        }
                        .frame(width: 68 + CGFloat(max(displayedImages.count - 1, 0)) * stackOffset,
                               height: 92,
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
                } else if let localImages = images.localImages, !localImages.isEmpty {
                    // Local images available: show them (before API response)
                    let displayedImages = Array(localImages.prefix(3))
                    let remainingCount = max(localImages.count - displayedImages.count, 0)
                    let stackOffset: CGFloat = 6
                    let sizeReduction: CGFloat = 4

                    ZStack(alignment: .topTrailing) {
                        ZStack(alignment: .leading) {
                            ForEach(Array(displayedImages.enumerated()), id: \.offset) { index, image in
                                let reverseIndex = displayedImages.count - 1 - index
                                let imageWidth = 68 - CGFloat(reverseIndex) * sizeReduction
                                let imageHeight = 92 - CGFloat(reverseIndex) * sizeReduction

                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: imageWidth, height: imageHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white, lineWidth: 0.4)
                                    )
                                    .shadow(radius: 4)
                                    .offset(x: CGFloat(index) * stackOffset)
                                    .zIndex(Double(index))
                            }
                        }
                        .frame(width: 68 + CGFloat(max(displayedImages.count - 1, 0)) * stackOffset,
                               height: 92,
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
                } else if product != nil {
                    // Product found but no images
                    Image("imagenotfound1")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 39, height: 34)
                } else {
                    // No product yet: show placeholder based on scan type
                    let placeholderImage = scan?.scan_type == "photo" ? "PhotoScanEmptyState" : "Barcodelinecorners"
                    Image(placeholderImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 88)
                        .clipped()
                }
            }
            .frame(width: 68, height: 92)
            .padding(.leading, 14)
            .layoutPriority(1)
            
            // Right-side: product info and status
            VStack(alignment: .leading) {
                if isSkeletonMode {
                    // Skeleton mode: show redacted placeholders
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.bar)
                        .opacity(0.4)
                        .frame(width: 185, height: 25)
                        .padding(.bottom, 4)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.bar)
                        .opacity(0.4)
                        .frame(width: 132, height: 20)
                        .padding(.bottom, 6)
                    RoundedRectangle(cornerRadius: 52)
                        .fill(.bar)
                        .opacity(0.4)
                        .frame(width: 79, height: 24)
                } else if isSubmitting {
                    // Submitting state (photo mode: image being uploaded)
                    VStack(alignment: .leading) {
                        Text("Submitting your photo…")
                            .font(ManropeFont.bold.size(12))
                            .foregroundColor(Color.white)
                            .padding(.bottom, 2)
                        Text("We're uploading the image to analyze")
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .font(ManropeFont.semiBold.size(10))
                            .foregroundColor(Color.white)
                        Spacer(minLength: 8)
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .tint(
                                    LinearGradient(
                                        colors: [Color(hex: "#A6A6A6"), Color(hex: "#818181")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .scaleEffect(1)
                                .frame(width: 16, height: 16)
                            Text("Submitting")
                                .font(NunitoFont.semiBold.size(12))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "#A6A6A6"), Color(hex: "#818181")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        .frame(width: 110, height: 22)
                        .padding(4)
                        .background(
                            Capsule()
                                .fill(.bar)
                        )
                    }
                } else if isPendingMode || (isLoading && scan == nil) {
                    // Loading state (barcode mode: looking up product)
                    VStack(alignment: .leading) {
                        Text("Looking up this product…")
                            .font(ManropeFont.bold.size(12))
                            .foregroundColor(Color.white)
                            .padding(.bottom, 2)
                        Text("We're checking our database for this Product")
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .font(ManropeFont.semiBold.size(10))
                            .foregroundColor(Color.white)
                        Spacer(minLength: 8)
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .tint(
                                    LinearGradient(
                                        colors: [Color(hex: "#A6A6A6"), Color(hex: "#818181")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .scaleEffect(1)
                                .frame(width: 16, height: 16)
                            Text("Fetching details")
                                .font(NunitoFont.semiBold.size(12))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "#A6A6A6"), Color(hex: "#818181")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        .frame(width: 130, height: 22)
                        .padding(4)
                        .background(
                            Capsule()
                                .fill(.bar)
                        )
                    }
                } else if let product = product {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.brand ?? "Brand not found")
                            .font(ManropeFont.regular.size(12))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if let productName = product.name, !productName.isEmpty {
                            Text(productName)
                                .font(NunitoFont.semiBold.size(16))
                                .foregroundColor(Color.white.opacity(0.85))
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 8)
                        
                        if isAnalyzing && ingredientRecommendations == nil {
                            // Analyzing state
                            HStack(spacing: 4) {
                                Image("analysisicon")
                                    .frame(width: 18, height: 18)
                                Text("Analyzing")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.leading, 8)
                            .padding(.trailing, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#3DA8F5"), Color(hex: "#3DACFB")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        } else if let matchStatus = matchStatus {
                            // Analysis complete: show match status
                            HStack(spacing: 4) {
                                Image(matchStatus.iconAssetName)
                                    .frame(width: 18, height: 18)
                                Text(matchStatus.displayText)
                                    .font(NunitoFont.bold.size(14))
                                    .foregroundColor(.white)
                            }
                            .padding(.leading, 8)
                            .padding(.trailing, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: matchStatus.gradientColors,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        } else if errorState != nil && product != nil {
                            // Error state with product: show retry button
                            Button(action: {
                                retryPolling()
                            }) {
                                HStack(spacing: 4) {
                                    Image("stasharrow-retry")
                                        .frame(width: 18, height: 18)
                                    Text("Retry")
                                        .font(NunitoFont.bold.size(12))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "#B5B5B5"), Color(hex: "#D3D3D3")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                onRetryShown?()
                            }
                        }
                    }
                } else if notFoundState {
                    VStack(alignment: .leading, spacing: 4) {
                        Spacer(minLength: 0)
                        Text("We couldn't identify this product")
                            .font(ManropeFont.bold.size(11))
                            .foregroundColor(Color.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        
                        Text("Help us identify it, add a few photos of the product.")
                            .font(ManropeFont.semiBold.size(10))
                            .foregroundColor(Color.white.opacity(0.9))
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                } else if let error = errorState, product == nil {
                    VStack(spacing: 4) {
                        Spacer(minLength: 0)
                        Text("Something went wrong")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.white)
                        Text(error)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.9))
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity,
                   minHeight: 92,
                   maxHeight: 92,
                   alignment: .leading
            )
            .onChange(of: errorState) { newErrorState in
                if newErrorState == nil && product != nil {
                    onRetryHidden?()
                }
            }
            .onChange(of: matchStatus) { newMatchStatus in
                if newMatchStatus != nil {
                    onRetryHidden?()
                }
            }
            
            // Right arrow indicator
            if scan != nil {
                HStack {
                    Image("iconamoon_arrow-up-2-duotone")
                        .frame(width: 24, height: 13)
                }
                .padding(.trailing, 14)
            }
        }
        .frame(width: 300, height: 120)
        .contentShape(Rectangle())
        .onTapGesture {
            if let product = product {
                onTap?(product, matchStatus, ingredientRecommendations, overallAnalysis, scanId)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.bar)
                .opacity(0.4)
        )
        .clipped()
        .task(id: scanId) {
            guard !scanId.isEmpty else { return }

            // If scanId starts with "pending_", show skeleton/loading state
            // Don't fetch from API for placeholder IDs
            if scanId.hasPrefix("pending_") {
                isLoading = true
                return
            }

            // Don't fetch from API for skeleton card (UI-only placeholder)
            if scanId == "skeleton" {
                isLoading = false
                return
            }

            // If isSubmitting, wait for submission to complete before fetching
            // This prevents premature getScan calls for photo mode
            if isSubmitting {
                print("[SCAN_CARD] ⏳ Waiting for submission to complete - scan_id: \(scanId)")
                return
            }

            // If initialScan is provided (from SSE or cache), use it directly
            // No API call, no polling - this is for barcode scans
            if let initialScan = initialScan {
                print("[SCAN_CARD] 📦 Using initialScan (SSE/cache) - scan_id: \(scanId), scan_type: \(initialScan.scan_type)")
                await MainActor.run {
                    self.scan = initialScan
                    cachedInitialScan = initialScan
                    self.isLoading = false
                    onResultUpdated?()

                    // Barcode scans are complete via SSE - no polling needed
                    if initialScan.state == "done" {
                        userPreferences.incrementScanCount()
                    }
                }
                return
            }

            // No initialScan - fetch via API (for photo scans and history items)
            await fetchScan()
        }
        .task(id: isSubmitting) {
            // Watch for submission completion (isSubmitting: true → false)
            // When submission completes, trigger getScan and re-poll
            // This happens for EVERY photo submission (not just first photo)
            // because each new photo may reveal additional product information
            print("[SCAN_CARD] 🎬 task(id: isSubmitting) triggered - isSubmitting: \(isSubmitting), scan_id: \(scanId)")
            
            if !isSubmitting && !scanId.isEmpty && !scanId.hasPrefix("pending_") && scanId != "skeleton" {
                print("[SCAN_CARD] 🔄 Submission completed, starting fetch/re-poll - scan_id: \(scanId)")

                // Cancel existing polling if running (for subsequent photos)
                // Set isPolling to false to allow new polling to start
                if isPolling {
                    print("[SCAN_CARD] ⏹️ Cancelling existing polling before starting new fetch - scan_id: \(scanId)")
                    pollingTask?.cancel()
                    pollingTask = nil
                    await MainActor.run {
                        isPolling = false
                    }
                }

                await fetchScan()
            } else {
                print("[SCAN_CARD] ⏭️ Skipping fetch - isSubmitting: \(isSubmitting), scanId: \(scanId)")
            }
        }
        .task(id: initialScan) {
            // Watch for changes in initialScan (e.g., when analysis arrives via SSE)
            // Since DTO.Scan is Hashable, this will trigger whenever the scan content changes
            if let initialScan = initialScan, initialScan.id == scanId {
                await MainActor.run {
                    // Only update if the scan data has actually changed
                    if cachedInitialScan != initialScan {
                        self.scan = initialScan
                        cachedInitialScan = initialScan
                        onResultUpdated?()
                        print("[SCAN_CARD] 🔄 Updated scan from initialScan change - scan_id: \(scanId), state: \(initialScan.state)")
                    }
                }
            }
        }
        .onDisappear {
            pollingTask?.cancel()
            pollingTask = nil
        }
    }
    
    private func fetchScan() async {
        // Photo scans may need to fetch even if initialScan is provided (for re-polling after subsequent photos)
        // Barcode scans with initialScan should not reach here (they use SSE)
        
        isLoading = true
        errorState = nil

        // Wait 2 seconds before first fetch for photo scans
        // This gives the server time to process the image after submission
        print("[SCAN_CARD] ⏳ Waiting 2 seconds before first fetch for photo scan - scan_id: \(scanId)")
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        do {
            print("[SCAN_CARD] 🔵 Fetching scan via API - scan_id: \(scanId) (photo scan or history)")
            let fetchedScan = try await webService.getScan(scanId: scanId)
            
            await MainActor.run {
                self.scan = fetchedScan
                self.isLoading = false
                onResultUpdated?()
                onScanUpdated?(fetchedScan)  // Update parent cache with fetched data
                
                // Only start polling for photo scans (not barcode scans)
                // Barcode scans use SSE and don't need polling
                if fetchedScan.scan_type == "photo" || fetchedScan.scan_type == "barcode_plus_photo" {
                    // Start polling if scan is not done yet
                    if fetchedScan.state != "done" {
                        print("[SCAN_CARD] ⏳ Starting polling for photo scan - scan_id: \(scanId), state: \(fetchedScan.state)")
                        startPolling()
                    } else {
                        // Scan is complete, increment scan count
                        print("[SCAN_CARD] ✅ Scan is done - scan_id: \(scanId)")
                        userPreferences.incrementScanCount()
                    }
                } else {
                    // Barcode scan - should not reach here if initialScan was provided
                    // But if it does, don't poll (analysis comes via SSE)
                    print("[SCAN_CARD] ⚠️ Barcode scan fetched via API - this should use initialScan instead")
                    if fetchedScan.state == "done" {
                        userPreferences.incrementScanCount()
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorState = error.localizedDescription
                self.isLoading = false
                print("[SCAN_CARD] ❌ Failed to fetch scan - scan_id: \(scanId), error: \(error.localizedDescription)")
            }
        }
    }
    
    private func startPolling() {
        // Prevent duplicate polling sessions
        guard pollingTask == nil && !isPolling else {
            print("[SCAN_CARD] ⚠️ Polling already active - skipping startPolling() - scan_id: \(scanId)")
            return
        }
        
        // Only poll for photo scans - barcode scans use SSE
        guard let currentScan = scan, currentScan.scan_type == "photo" else {
            print("[SCAN_CARD] ⚠️ startPolling() called but scan is not a photo scan - skipping")
            return
        }
        
        print("[SCAN_CARD] ⏳ Starting polling for photo scan - scan_id: \(scanId)")
        isPolling = true
        
        pollingTask = Task {
            var pollCount = 0
            
            while !Task.isCancelled {
                pollCount += 1
                
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    
                    print("[SCAN_CARD] 🔄 Poll #\(pollCount) - scan_id: \(scanId) (photo scan)")
                    let fetchedScan = try await webService.getScan(scanId: scanId)
                    
                    await MainActor.run {
                        self.scan = fetchedScan
                        onResultUpdated?()
                        onScanUpdated?(fetchedScan)  // Update parent cache with latest data

                        // Stop polling if scan is done
                        if fetchedScan.state == "done" {
                            print("[SCAN_CARD] ✅ Polling complete - scan_id: \(scanId), state: done")
                            pollingTask?.cancel()
                            pollingTask = nil
                            isPolling = false
                            userPreferences.incrementScanCount()
                        }
                    }
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.errorState = error.localizedDescription
                            print("[SCAN_CARD] ❌ Poll error - scan_id: \(scanId), error: \(error.localizedDescription)")
                            pollingTask?.cancel()
                            pollingTask = nil
                            isPolling = false
                        }
                    }
                    break
                }
            }
        }
    }
    
    private func retryPolling() {
        errorState = nil
        pollingTask?.cancel()
        pollingTask = nil
        Task {
            await fetchScan()
        }
    }
}

// MARK: - Product Image Thumbnail Component
private struct ScanProductImageThumbnail: View {
    let imageLocation: DTO.ImageLocationInfo
    let isAnalyzing: Bool

    @Environment(WebService.self) private var webService
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // When the image cannot be loaded from the server, fall back to placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.bar.opacity(0.4))
                        .frame(width: 68, height: 92)
                    Image("imagenotfound1")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 39, height: 34)
                }
            }

            if isAnalyzing {
                Color.black.opacity(0.25)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(width: 68, height: 92)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .tint(.white)
            }
        }
        .clipped()
        .task(id: imageLocationKey) {
            guard image == nil else { return }
            if let uiImage = try? await webService.fetchImage(imageLocation: imageLocation, imageSize: .small) {
                image = uiImage
            }
        }
    }

    private var imageLocationKey: String {
        switch imageLocation {
        case .url(let url):
            return url.absoluteString
        case .imageFileHash(let hash):
            return hash
        }
    }
}

