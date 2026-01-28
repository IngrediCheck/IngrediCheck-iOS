import SwiftUI
import os

/// Unified card component that displays scan data for both barcode and photo scans
/// Takes a scanId and optionally initialScan data (from SSE events or cache)
/// If initialScan is provided, uses it directly (no API call, no polling) - for barcode scans
/// If initialScan is nil, fetches via getScan and polls if needed - for photo scans
struct ScanDataCard: View {
    let scanId: String
    var initialScan: DTO.Scan? = nil  // Optional initial scan data (from SSE or cache)
    var isSubmitting: Bool = false  // If true, image is being submitted to API (prevents premature getScan)
    var localImages: [(image: UIImage, hash: String)]? = nil  // Locally captured images with hash (shown before API response, hash used for matching)
    var cameraModeType: String = "barcode"  // Current camera mode type ("barcode" or "photo") for skeleton/pending states
    var onRetryShown: (() -> Void)? = nil
    var onRetryHidden: (() -> Void)? = nil
    var onResultUpdated: (() -> Void)? = nil
    var onScanUpdated: ((DTO.Scan) -> Void)? = nil  // NEW: Called when scan data updates (for cache sync)
    var onFavoriteToggle: ((String, Bool) -> Void)? = nil // NEW: Callback for favorite toggle
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
    // Uses cameraModeType for skeleton/pending modes, otherwise uses scan data
    private var scanType: String {
        // For skeleton/pending modes, use the passed cameraModeType
        if isSkeletonMode || isPendingMode {
            return cameraModeType
        }
        // For actual scans, use the scan's type or fall back to cameraModeType
        return scan?.scan_type ?? cameraModeType
    }
    
    // Computed property to determine which images to display
    // Returns separate arrays for inventory images, user images, and pending local images
    // Stack order (front to back): pending local → user → inventory (reversed)
    private var imagesToDisplay: (
        inventoryImages: [DTO.ImageLocationInfo],
        userImages: [DTO.ImageLocationInfo],
        pendingLocalImages: [UIImage]
    ) {
        var inventoryImages: [DTO.ImageLocationInfo] = []
        var userImages: [DTO.ImageLocationInfo] = []
        var processedHashes: Set<String> = []  // Track which hashes are already processed

        // Extract images from scan.images (has type information)
        if let scan = scan {
            for scanImage in scan.images {
                switch scanImage {
                case .inventory(let img):
                    if let url = URL(string: img.url) {
                        inventoryImages.append(.url(url))
                    }
                case .user(let img):
                    if img.status == "processed", let storagePath = img.storage_path {
                        userImages.append(.scanImagePath(storagePath))
                        processedHashes.insert(img.content_hash)  // Mark as processed
                    }
                }
            }
        }

        // Filter local images - only show those NOT yet processed by API
        // This prevents duplicate display of the same image
        var pendingLocalImages: [UIImage] = []
        if let locals = localImages {
            for (image, hash) in locals {
                if !processedHashes.contains(hash) {
                    pendingLocalImages.append(image)
                }
            }
        }

        return (inventoryImages: inventoryImages, userImages: userImages, pendingLocalImages: pendingLocalImages)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left-side visual: product images or placeholder
            productImageView
                .frame(width: 68, height: 92)
                .padding(.leading, 14)
                .layoutPriority(1)

            // Right-side: product info and status
            productInfoView
                .frame(maxWidth: .infinity,
                       minHeight: 92,
                       maxHeight: 92,
                       alignment: .leading
                )
                .padding(.trailing, 14)
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
                Log.debug("SCAN_CARD", "⏳ Waiting for submission to complete - scan_id: \(scanId)")
                return
            }

            // If initialScan is provided (from SSE or cache), use it directly
            // No API call, no polling - this is for barcode scans
            if let initialScan = initialScan {
                Log.debug("SCAN_CARD", "📦 Using initialScan (SSE/cache) - scan_id: \(scanId), scan_type: \(initialScan.scan_type)")
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
            Log.debug("SCAN_CARD", "🎬 task(id: isSubmitting) triggered - isSubmitting: \(isSubmitting), scan_id: \(scanId)")
            
            if !isSubmitting && !scanId.isEmpty && !scanId.hasPrefix("pending_") && scanId != "skeleton" {
                Log.debug("SCAN_CARD", "🔄 Submission completed, starting fetch/re-poll - scan_id: \(scanId)")

                // Cancel existing polling if running (for subsequent photos)
                // Set isPolling to false to allow new polling to start
                if isPolling {
                    Log.debug("SCAN_CARD", "⏹️ Cancelling existing polling before starting new fetch - scan_id: \(scanId)")
                    pollingTask?.cancel()
                    pollingTask = nil
                    await MainActor.run {
                        isPolling = false
                    }
                }

                await fetchScan()
            } else {
                Log.debug("SCAN_CARD", "⏭️ Skipping fetch - isSubmitting: \(isSubmitting), scanId: \(scanId)")
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
                        Log.debug("SCAN_CARD", "🔄 Updated scan from initialScan change - scan_id: \(scanId), state: \(initialScan.state)")
                    }
                }
            }
        }
        .onDisappear {
            pollingTask?.cancel()
            pollingTask = nil
        }
    }
    
    // MARK: - Product Image View
    @ViewBuilder
    private var productImageView: some View {
        ZStack {
            let images = imagesToDisplay
            let hasAnyImages = !images.inventoryImages.isEmpty ||
                              !images.userImages.isEmpty ||
                              !images.pendingLocalImages.isEmpty

            if isSkeletonMode {
                // Skeleton mode: show empty state placeholder image
                let placeholderImage = scanType == "photo" ? "PhotoScanEmptyState" : "Barcodelinecorners"
                Image(placeholderImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 88)
                    .clipped()
            } else if isPendingMode || (isLoading && scan == nil && images.pendingLocalImages.isEmpty) {
                // Loading state: show placeholder (only if no local images to show)
                ProgressView()
                    .tint(.white.opacity(0.6))
            } else if hasAnyImages {
                // Combined images stack: local (with loader) → user → inventory (reversed)
                combinedImagesStackView(
                    inventoryImages: images.inventoryImages,
                    userImages: images.userImages,
                    localImages: images.pendingLocalImages
                )
            } else if product != nil {
                // Product found but no images
                Image("imagenotfound1")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 39, height: 34)
            } else {
                // No product yet: show placeholder based on scan type
                let placeholderImage = (scan?.scan_type == "photo" || scan?.scan_type == "barcode_plus_photo") ? "PhotoScanEmptyState" : "Barcodelinecorners"
                Image(placeholderImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 88)
                    .clipped()
            }
        }
    }
    
    // MARK: - API Images Stack View
    @ViewBuilder
    private func apiImagesStackView(images: [DTO.ImageLocationInfo]) -> some View {
        // Reverse the images array so the last API image appears at the front of the stack
        let reversedImages = Array(images.reversed())
        let displayedImages = Array(reversedImages.prefix(3))
        let totalCount = images.count
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

            if totalCount > 3 {
                totalCountBadge(count: totalCount)
            }
        }
    }
    
    // MARK: - Local Images Stack View
    @ViewBuilder
    private func localImagesStackView(images: [UIImage]) -> some View {
        let displayedImages = Array(images.prefix(3))
        let totalCount = images.count
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

            if totalCount > 3 {
                totalCountBadge(count: totalCount)
            }
        }
    }

    // MARK: - Combined Images Stack View
    /// Displays images in priority order: local (with loader) → user → inventory (reversed)
    @ViewBuilder
    private func combinedImagesStackView(
        inventoryImages: [DTO.ImageLocationInfo],
        userImages: [DTO.ImageLocationInfo],
        localImages: [UIImage]
    ) -> some View {
        // Reverse inventory images so last appears at front of its section
        let reversedInventory = Array(inventoryImages.reversed())

        // Build combined display array
        // Order (front to back): localImages → userImages → reversedInventory
        let totalCount = localImages.count + userImages.count + inventoryImages.count
        let displayLimit = 3
        let stackOffset: CGFloat = 6
        let sizeReduction: CGFloat = 4

        // Build display items using helper function
        let displayedItems = Array(buildDisplayItems(
            localImages: localImages,
            userImages: userImages,
            reversedInventory: reversedInventory
        ).prefix(displayLimit))

        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .leading) {
                ForEach(Array(displayedItems.enumerated()), id: \.element.id) { index, item in
                    let reverseIndex = displayedItems.count - 1 - index
                    let imageWidth = 68 - CGFloat(reverseIndex) * sizeReduction
                    let imageHeight = 92 - CGFloat(reverseIndex) * sizeReduction

                    switch item.content {
                    case .local(let image):
                        // Local image with loader overlay
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: imageWidth, height: imageHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                // Loader overlay for uploading images
                                ZStack {
                                    Color.black.opacity(0.25)
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .tint(.white)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white, lineWidth: 0.4)
                            )
                            .shadow(radius: 4)
                            .offset(x: CGFloat(index) * stackOffset)
                            .zIndex(Double(index))

                    case .api(let location):
                        // API image (user or inventory)
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
            }
            .frame(width: 68 + CGFloat(max(displayedItems.count - 1, 0)) * stackOffset,
                   height: 92,
                   alignment: .leading)

            if totalCount > 3 {
                totalCountBadge(count: totalCount)
            }
        }
    }

    /// Helper to build display items array (moved outside @ViewBuilder)
    private func buildDisplayItems(
        localImages: [UIImage],
        userImages: [DTO.ImageLocationInfo],
        reversedInventory: [DTO.ImageLocationInfo]
    ) -> [CombinedImageDisplayItem] {
        var displayItems: [CombinedImageDisplayItem] = []

        // First: local images (with loader)
        for image in localImages {
            displayItems.append(CombinedImageDisplayItem(content: .local(image), showLoader: true))
        }

        // Second: user images (processed, no loader)
        for location in userImages {
            displayItems.append(CombinedImageDisplayItem(content: .api(location), showLoader: false))
        }

        // Third: inventory images (reversed, no loader)
        for location in reversedInventory {
            displayItems.append(CombinedImageDisplayItem(content: .api(location), showLoader: false))
        }

        return displayItems
    }
    
    // MARK: - Total Count Badge
    @ViewBuilder
    private func totalCountBadge(count: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.black)
        }
        .frame(width: 22, height: 22)
        .offset(x: 2, y: -3)
    }
    
    // MARK: - Product Info View
    @ViewBuilder
    private var productInfoView: some View {
        VStack(alignment: .leading) {
            if isSkeletonMode {
                skeletonPlaceholders
            } else if isSubmitting {
                submittingStateView
            } else if isPendingMode || (isLoading && scan == nil) {
                loadingStateView
            } else if let product = product {
                productDetailsView(product: product)
            } else if notFoundState {
                notFoundView
            } else if let error = errorState, product == nil {
                errorView(error: error)
            }
        }
    }
    
    // MARK: - Skeleton Placeholders
    @ViewBuilder
    private var skeletonPlaceholders: some View {
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
    }
    
    // MARK: - Submitting State View
    @ViewBuilder
    private var submittingStateView: some View {
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
            statusBadge(text: "Submitting", colors: [Color(hex: "#A6A6A6"), Color(hex: "#818181")], width: 110)
        }
    }
    
    // MARK: - Loading State View
    @ViewBuilder
    private var loadingStateView: some View {
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
            statusBadge(text: "Fetching details", colors: [Color(hex: "#A6A6A6"), Color(hex: "#818181")], width: 130)
        }
    }
    
    // MARK: - Status Badge
    @ViewBuilder
    private func statusBadge(text: String, colors: [Color], width: CGFloat) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .tint(
                    LinearGradient(
                        colors: colors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(1)
                .frame(width: 16, height: 16)
            Text(text)
                .font(NunitoFont.semiBold.size(12))
                .foregroundStyle(
                    LinearGradient(
                        colors: colors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .frame(width: width, height: 22)
        .padding(4)
        .background(
            Capsule()
                .fill(.bar)
        )
    }
    
    // MARK: - Product Details View
    @ViewBuilder
    private func productDetailsView(product: DTO.Product) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Top row: Name + Heart button
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    if let productName = product.name, !productName.isEmpty {
                        Text(productName)
                            .font(NunitoFont.semiBold.size(14))
                            .foregroundColor(Color.white.opacity(0.85))
                            .lineLimit(2)
                    }
                    if let brand = product.brand, !brand.isEmpty {
                        Text(brand)
                            .font(ManropeFont.regular.size(12))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Heart button (top right)
                heartButton(isFavorited: scan?.is_favorited ?? false)
            }

            Spacer(minLength: 4)

            // Bottom row: Status badge + Chevron
            HStack {
                if isAnalyzing && ingredientRecommendations == nil {
                    analyzingBadge
                } else if let matchStatus = matchStatus {
                    matchStatusBadge(matchStatus: matchStatus)
                } else if errorState != nil {
                    retryButton
                }

                Spacer()

                // Chevron disclosure icon (bottom right)
                chevronIcon
            }
        }
    }

    // MARK: - Chevron Icon
    @ViewBuilder
    private var chevronIcon: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .regular))
            .foregroundColor(.white)
    }
    
    // MARK: - Heart Button
    @ViewBuilder
    private func heartButton(isFavorited: Bool) -> some View {
        Button(action: {
            onFavoriteToggle?(scanId, !isFavorited)
        }) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isFavorited ? Color(hex: "#FF4D4D") : .white)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Analyzing Badge
    @ViewBuilder
    private var analyzingBadge: some View {
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
    }
    
    // MARK: - Match Status Badge
    @ViewBuilder
    private func matchStatusBadge(matchStatus: DTO.ProductRecommendation) -> some View {
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
    }
    
    // MARK: - Retry Button
    @ViewBuilder
    private var retryButton: some View {
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
    
    // MARK: - Not Found View
    @ViewBuilder
    private var notFoundView: some View {
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
    }
    
    // MARK: - Error View
    @ViewBuilder

    private func errorView(error: String) -> some View {
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
    
    private func fetchScan() async {
        // Photo scans may need to fetch even if initialScan is provided (for re-polling after subsequent photos)
        // Barcode scans with initialScan should not reach here (they use SSE)
        
        isLoading = true
        errorState = nil

        // Wait 2 seconds before first fetch for photo scans
        // This gives the server time to process the image after submission
        Log.debug("SCAN_CARD", "⏳ Waiting 2 seconds before first fetch for photo scan - scan_id: \(scanId)")
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        do {
            Log.debug("SCAN_CARD", "🔵 Fetching scan via API - scan_id: \(scanId) (photo scan or history)")
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
                        Log.debug("SCAN_CARD", "⏳ Starting polling for photo scan - scan_id: \(scanId), state: \(fetchedScan.state)")
                        startPolling()
                    } else {
                        // Scan is complete, increment scan count
                        Log.debug("SCAN_CARD", "✅ Scan is done - scan_id: \(scanId)")
                        userPreferences.incrementScanCount()
                    }
                } else {
                    // Barcode scan - should not reach here if initialScan was provided
                    // But if it does, don't poll (analysis comes via SSE)
                    Log.warning("SCAN_CARD", "⚠️ Barcode scan fetched via API - this should use initialScan instead")
                    if fetchedScan.state == "done" {
                        userPreferences.incrementScanCount()
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorState = error.localizedDescription
                self.isLoading = false
                Log.error("SCAN_CARD", "❌ Failed to fetch scan - scan_id: \(scanId), error: \(error.localizedDescription)")
            }
        }
    }
    
    private func startPolling() {
        // Prevent duplicate polling sessions
        guard pollingTask == nil && !isPolling else {
            Log.warning("SCAN_CARD", "⚠️ Polling already active - skipping startPolling() - scan_id: \(scanId)")
            return
        }
        
        // Only poll for photo scans and barcode_plus_photo scans - barcode scans use SSE
        guard let currentScan = scan, (currentScan.scan_type == "photo" || currentScan.scan_type == "barcode_plus_photo") else {
            Log.warning("SCAN_CARD", "⚠️ startPolling() called but scan is not a photo or barcode_plus_photo scan - skipping")
            return
        }
        
        Log.debug("SCAN_CARD", "⏳ Starting polling for \(currentScan.scan_type) scan - scan_id: \(scanId)")
        isPolling = true
        
        pollingTask = Task {
            var pollCount = 0
            
            
            while !Task.isCancelled {
                pollCount += 1
                
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    
                    Log.debug("SCAN_CARD", "🔄 Poll #\(pollCount) - scan_id: \(scanId) (photo scan)")
                    let fetchedScan = try await webService.getScan(scanId: scanId)
                    
                    await MainActor.run {
                        self.scan = fetchedScan
                        onResultUpdated?()
                        onScanUpdated?(fetchedScan)  // Update parent cache with latest data

                        // Stop polling if scan is done
                        if fetchedScan.state == "done" {
                            Log.debug("SCAN_CARD", "✅ Polling complete - scan_id: \(scanId), state: done")
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
                            Log.error("SCAN_CARD", "❌ Poll error - scan_id: \(scanId), error: \(error.localizedDescription)")
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

// MARK: - Combined Image Display Item
/// Helper struct for combined image stack display
private struct CombinedImageDisplayItem: Identifiable {
    let id = UUID()
    enum Content {
        case local(UIImage)
        case api(DTO.ImageLocationInfo)
    }
    let content: Content
    let showLoader: Bool
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
            do {
                Log.debug("ScanDataCard", "Fetching thumbnail: \(imageLocationKey)")
                let uiImage = try await webService.fetchImage(imageLocation: imageLocation, imageSize: .small)
                await MainActor.run {
                    image = uiImage
                }
            } catch {
                Log.error("ScanDataCard", "❌ Thumbnail fetch failed: \(error)")
            }
        }
    }

    private var imageLocationKey: String {
        switch imageLocation {
        case .url(let url):
            return url.absoluteString
        case .imageFileHash(let hash):
            return hash
        case .scanImagePath(let path):
            return path
        }
    }
}

// MARK: - Previews

#if DEBUG
// Sample scan data for previews (without analysis result since it requires Decoder)
private func makeSampleScan(
    state: String = "done",
    name: String? = "Sample Product",
    brand: String? = "Sample Brand",
    ingredients: [DTO.Ingredient] = [
        DTO.Ingredient(name: "Water", vegan: true, vegetarian: true, ingredients: []),
        DTO.Ingredient(name: "Sugar", vegan: true, vegetarian: true, ingredients: [])
    ]
) -> DTO.Scan {
    let productInfo = DTO.ScanProductInfo(
        name: name,
        brand: brand,
        ingredients: ingredients,
        images: nil,
        claims: ["Vegan"]
    )
    
    return DTO.Scan(
        id: "preview-scan-id",
        scan_type: "barcode",
        barcode: "1234567890",
        state: state,
        product_info: productInfo,
        product_info_source: "openfoodfacts",
        analysis_result: nil,  // Can't create ScanAnalysisResult without Decoder
        images: [],
        latest_guidance: nil,
        created_at: "2025-01-05T10:00:00Z",
        last_activity_at: "2025-01-05T10:00:00Z"
    )
}

#Preview("Skeleton Loading") {
    ScanDataCard(scanId: "skeleton")
        .environment(WebService())
        .environment(AppState())
        .environment(UserPreferences())
        .frame(height: 120)
        .padding()
}

#Preview("Analyzing State") {
    ScanDataCard(
        scanId: "preview-1",
        initialScan: makeSampleScan(state: "analyzing")
    )
    .environment(WebService())
    .environment(AppState())
    .environment(UserPreferences())
    .frame(height: 120)
    .padding()
}

#Preview("Product with Ingredients") {
    ScanDataCard(
        scanId: "preview-2",
        initialScan: makeSampleScan()
    )
    .environment(WebService())
    .environment(AppState())
    .environment(UserPreferences())
    .frame(height: 120)
    .padding()
}

#Preview("Missing Ingredients") {
    ScanDataCard(
        scanId: "preview-3",
        initialScan: makeSampleScan(ingredients: [])
    )
    .environment(WebService())
    .environment(AppState())
    .environment(UserPreferences())
    .frame(height: 120)
    .padding()
}

#Preview("Pending Mode") {
    ScanDataCard(scanId: "pending_12345")
        .environment(WebService())
        .environment(AppState())
        .environment(UserPreferences())
        .frame(height: 120)
        .padding()
}
#endif
