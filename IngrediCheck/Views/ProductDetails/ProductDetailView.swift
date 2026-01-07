//
//  ProductDetailView.swift
//  IngrediCheckPreview
//
//  Created on 18/11/25.
//

import SwiftUI

enum ProductDetailPresentationSource {
    case homeView
    case cameraView
}

struct ProductDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WebService.self) private var webService
    @Environment(UserPreferences.self) private var userPreferences

    @State private var isFavorite = false
    @State private var isIngredientsExpanded = false
    @State private var isIngredientsAlertExpanded = false
    @State private var selectedImageIndex = 0
    @State private var activeIngredientHighlight: IngredientHighlight?
    @State private var isCameraPresentedFromDetail = false
    @State private var isImageViewerPresented = false
    @State private var isReanalyzingLocally = false  // Temporary state to show analyzing UI immediately

    // Real-time scan observation (new approach)
    var scanId: String? = nil  // If provided, view will fetch/poll for scan updates
    var initialScan: DTO.Scan? = nil  // Initial scan data (if from cache/SSE)
    @State private var scan: DTO.Scan? = nil  // Current scan data (updates via polling)
    @State private var pollingTask: Task<Void, Never>? = nil

    // Legacy static data (old approach - kept for backwards compatibility)
    var product: DTO.Product? = nil
    var matchStatus: DTO.ProductRecommendation? = nil
    var ingredientRecommendations: [DTO.IngredientRecommendation]? = nil
    var overallAnalysis: String? = nil
    var localImages: [UIImage]? = nil  // Local images captured in photo mode
    var isPlaceholderMode: Bool = false

    // Presentation source tracking
    var presentationSource: ProductDetailPresentationSource = .homeView

    // Bindings for camera control (when presented from CameraView)
    var onRequestCameraWithScan: ((String) -> Void)? = nil

    private let fallbackProductStatus: ProductMatchStatus = .unknown

    // Compute product from scan if scanId mode, otherwise use legacy product
    private var resolvedProduct: DTO.Product? {
        if let scan = scan {
            return scan.toProduct()
        }
        return product
    }

    // Compute matchStatus from scan if scanId mode, otherwise use legacy matchStatus
    private var resolvedMatchStatus: DTO.ProductRecommendation? {
        if let scan = scan {
            return scan.toProductRecommendation()
        }
        return matchStatus
    }

    // Compute ingredientRecommendations from scan if scanId mode, otherwise use legacy
    private var resolvedIngredientRecommendations: [DTO.IngredientRecommendation]? {
        if let scan = scan {
            return scan.analysis_result?.toIngredientRecommendations()
        }
        return ingredientRecommendations
    }

    // Compute overallAnalysis from scan if scanId mode, otherwise use legacy
    private var resolvedOverallAnalysis: String? {
        if let scan = scan {
            return scan.analysis_result?.overall_analysis
        }
        return overallAnalysis
    }

    private var resolvedIsStale: Bool {
        return scan?.analysis_result?.is_stale ?? false
    }

    // Check if analysis is in progress


    private var isAnalyzing: Bool {
        isReanalyzingLocally || scan?.state == "analyzing" || scan?.state == "processing_images" || scan?.state == "fetching_product_info"
    }

    // Combined images: local images (if available) take priority over API images
    // This ensures photo mode shows the user's captured images
    enum ProductImage: Identifiable {
        case local(UIImage)
        case api(DTO.ImageLocationInfo)

        var id: String {
            switch self {
            case .local(let image):
                return "local_\(image.hashValue)"
            case .api(let location):
                switch location {
                case .url(let url):
                    return "api_\(url.absoluteString)"
                case .imageFileHash(let hash):
                    return "api_\(hash)"
                case .scanImagePath(let path):
                    return "api_\(path)"
                }
            }
        }
    }

    private var allImages: [ProductImage] {
        var images: [ProductImage] = []

        // Add local images first (photo mode)
        if let localImages = localImages, !localImages.isEmpty {
            images.append(contentsOf: localImages.map { ProductImage.local($0) })
        }

        // Add API images if no local images or as additional images
        if let product = resolvedProduct, !product.images.isEmpty {
            // If we have local images, only add API images if they're different
            // For now, just add API images after local images
            if localImages == nil || localImages?.isEmpty == true {
                images.append(contentsOf: product.images.map { ProductImage.api($0) })
            }
        }

        return images
    }

    // Dietary tags from product claims (API now includes emojis in claim text)
    private var dietaryTags: [DietaryTag] {
        guard let claims = resolvedProduct?.claims, !claims.isEmpty else {
            return []
        }

        // Directly map claims to DietaryTag (emojis already included from API)
        return claims.map { DietaryTag(claim: $0) }
    }
    
    // Check if product has images/name but missing ingredients
    private var hasMissingIngredients: Bool {
        guard let product = resolvedProduct else { return false }
        // Has product info (name or brand or images) but no ingredients
        let hasProductInfo = product.name != nil || product.brand != nil || !product.images.isEmpty || !allImages.isEmpty
        let hasNoIngredients = product.ingredients.isEmpty
        return hasProductInfo && hasNoIngredients && !isPlaceholderMode && !isAnalyzing
    }
    // Removed hardcoded descriptionText - now using resolvedDescriptionText computed property
    
    // Removed hardcoded ingredientAlertItems - now using resolvedIngredientAlertItems computed property
    
    // Removed hardcoded ingredientParagraphs - now using resolvedIngredientParagraphs computed property
    
    private var resolvedBrand: String {
        if let brand = resolvedProduct?.brand, !brand.isEmpty {
            return brand
        }
        return ""
    }
    
    private var resolvedName: String {
        if let name = resolvedProduct?.name, !name.isEmpty {
            return name
        }
        return "Unknown Product"
    }
    
    private var resolvedDetails: String {
        // API doesn't provide a separate "details" field like "Instant Noodles · Pack of 70g"
        // This field is not part of the Scan API response, so we don't display it
        // Instead, product name and brand are shown separately above
        return ""  // Return empty string - don't show hardcoded fallback
    }
    
    private var resolvedStatus: ProductMatchStatus {
        // Show "analyzing" status if analysis is in progress
        if isAnalyzing {
            return .analyzing
        }

        guard let matchStatus = resolvedMatchStatus else {
            return fallbackProductStatus
        }
        switch matchStatus {
        case .match:
            return .matched
        case .needsReview:
            return .uncertain
        case .notMatch:
            return .unmatched
        case .unknown:
            return .unknown
        }
    }
    

    private var resolvedIngredientAlertItems: [IngredientAlertItem] {
        guard let ingredientRecommendations = resolvedIngredientRecommendations else {
            return []
        }

        return ingredientRecommendations
            .filter { $0.safetyRecommendation != .safe }  // Only show flagged ingredients
            .map { recommendation in
                let status: IngredientAlertStatus = recommendation.safetyRecommendation == .definitelyUnsafe ? .unmatched : .uncertain
                
                // Find analysis matching this ingredient to get vote status
                let analysis = scan?.analysis_result?.ingredient_analysis.first { $0.ingredient == recommendation.ingredientName }
                
                return IngredientAlertItem(
                    name: recommendation.ingredientName,
                    detail: recommendation.reasoning,
                    status: status,
                    memberIdentifiers: recommendation.memberIdentifiers,  // Use memberIdentifiers array
                    vote: analysis?.vote,
                    rawIngredientName: analysis?.ingredient
                )
            }
    }
    
    private var resolvedIngredientParagraphs: [IngredientParagraph] {
        guard let product = resolvedProduct else {
            print("[ProductDetailView] ⚠️ No product data available for ingredients")
            return []
        }
        
        guard !product.ingredients.isEmpty else {
            print("[ProductDetailView] ⚠️ Product ingredients array is empty - product.name: \(product.name ?? "nil"), product.brand: \(product.brand ?? "nil")")
            return []
        }
        
        // Use ingredientsListAsString to format ingredients properly (handles nested ingredients)
        let ingredientsString = product.ingredientsListAsString
        
        if ingredientsString.isEmpty {
            print("[ProductDetailView] ⚠️ ingredientsListAsString returned empty string despite non-empty ingredients array")
            return []
        }
        
        print("[ProductDetailView] ✅ Ingredients available - count: \(product.ingredients.count), string length: \(ingredientsString.count)")
        
        // Create highlights from ingredientRecommendations
        var highlights: [IngredientHighlight] = []
        if let recommendations = ingredientRecommendations {
            for recommendation in recommendations {
                // Only create highlights for flagged ingredients
                if recommendation.safetyRecommendation != .safe {
                    highlights.append(IngredientHighlight(
                        phrase: recommendation.ingredientName,
                        reason: recommendation.reasoning
                    ))
                }
            }
        }
        
        return [IngredientParagraph(
            title: nil,
            body: ingredientsString,
            highlights: highlights
        )]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Gallery section - never redacted, shows placeholder images
                    productGallery
                        .unredacted()
                    
                    // Content sections - redacted in placeholder mode
                    Group {
                        productInformation
                        dietaryTagsRow
                        
                        // Show Missing Ingredients UI or regular content
                        if hasMissingIngredients {
                            missingIngredientsView
                        } else {
                            if !resolvedIngredientAlertItems.isEmpty || resolvedStatus == .matched {
                                IngredientsAlertCard(
                                    isExpanded: $isIngredientsAlertExpanded,
                                    items: resolvedIngredientAlertItems,
                                    status: resolvedStatus,
                                    overallAnalysis: resolvedOverallAnalysis,
                                    ingredientRecommendations: resolvedIngredientRecommendations,
                                    onFeedback: { item, voteType in
                                        handleIngredientFeedback(item: item, voteType: voteType)
                                    }
                                )
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                            

                            CollapsibleSection(
                                title: "Ingredients",
                                isExpanded: $isIngredientsExpanded
                            ) {
                                if resolvedIngredientParagraphs.isEmpty {
                                    Text("No ingredients available")
                                        .font(ManropeFont.regular.size(14))
                                        .foregroundStyle(.grayScale100)
                                        .lineSpacing(4)
                                } else {
                                    IngredientDetailsView(
                                        paragraphs: resolvedIngredientParagraphs,
                                        activeHighlight: $activeIngredientHighlight,
                                        highlightColor: resolvedStatus.color
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                    .redacted(reason: isPlaceholderMode ? .placeholder : [])
                }
            }
        }
        .background(Color(hex: "FFFFFF"))
        .navigationBarBackButtonHidden(true)
        .onChange(of: isIngredientsExpanded) { _, expanded in
            if !expanded {
                activeIngredientHighlight = nil
            }
        }
        .fullScreenCover(isPresented: $isCameraPresentedFromDetail) {
            ScanCameraViewWrapper(initialScanId: scanId, initialMode: .photo)
        }
        .fullScreenCover(isPresented: $isImageViewerPresented) {
            FullScreenImageViewer(
                images: allImages,
                selectedIndex: $selectedImageIndex
            )
        }
        .task(id: scanId) {
            // If scanId is provided, fetch and poll for scan updates
            guard let scanId = scanId, !scanId.isEmpty else { return }

            // If initialScan is provided, use it directly
            if let initialScan = initialScan {
                print("[ProductDetailView] 📦 Using initialScan - scan_id: \(scanId)")
                await MainActor.run {
                    self.scan = initialScan
                }

                // If barcode scan (has initialScan), no polling needed - SSE handles updates
                return
            }

            // Photo scan: fetch and poll for updates
            print("[ProductDetailView] 🔵 Fetching scan for photo mode - scan_id: \(scanId)")
            await fetchAndPollScan(scanId: scanId)
        }
        .task(id: initialScan) {
            // Watch for changes in initialScan (e.g., SSE updates for barcode scans)
            if let initialScan = initialScan, let scanId = scanId, initialScan.id == scanId {
                await MainActor.run {
                    self.scan = initialScan
                    // Update favorite state from scan
                    self.isFavorite = initialScan.is_favorited ?? false
                    print("[ProductDetailView] 🔄 Updated scan from initialScan change - scan_id: \(scanId), state: \(initialScan.state)")
                }
            }
        }
        .task(id: scan?.is_favorited) {
            // Update favorite state whenever scan favorite status changes
            if let isFavorited = scan?.is_favorited {
                await MainActor.run {
                    self.isFavorite = isFavorited
                }
            }
        }
        .onDisappear {
            // Cancel polling when view disappears
            pollingTask?.cancel()
            pollingTask = nil
        }
    }

    // MARK: - Favorite Toggle

    private func toggleFavorite() {
        // Determine which ID to use for favoriting
        // Priority: scanId > product data (shouldn't happen without scanId in new flow)
        guard let favoriteId = scanId else {
            print("[FAVORITE] ⚠️ Cannot favorite - no scanId available")
            return
        }

        // Optimistically update UI
        let previousState = isFavorite
        isFavorite = !previousState

        // Call API - toggleFavorite returns the actual new state
        Task {
            do {
                let newFavoriteState = try await webService.toggleFavorite(scanId: favoriteId)
                
                // Update with server's response (in case of race conditions)
                await MainActor.run {
                    self.isFavorite = newFavoriteState
                }

                // Update scan object with new favorite status
                if let currentScan = scan {
                    let updatedScan = DTO.Scan(
                        id: currentScan.id,
                        scan_type: currentScan.scan_type,
                        barcode: currentScan.barcode,
                        state: currentScan.state,
                        product_info: currentScan.product_info,
                        product_info_source: currentScan.product_info_source,
                        analysis_result: currentScan.analysis_result,
                        images: currentScan.images,
                        latest_guidance: currentScan.latest_guidance,
                        created_at: currentScan.created_at,
                        last_activity_at: currentScan.last_activity_at,
                        is_favorited: newFavoriteState,
                        analysis_id: currentScan.analysis_id
                    )

                    await MainActor.run {
                        self.scan = updatedScan
                    }
                }
            } catch {
                print("[FAVORITE] ❌ Failed to toggle favorite - scanId: \(favoriteId), error: \(error.localizedDescription)")

                // Revert UI on error
                await MainActor.run {
                    self.isFavorite = previousState
                }
            }
        }
    }

    private func performReanalysis() {
        guard let scanId = scanId else { return }
        
        Task {
            do {
                print("[ProductDetailView] 🔄 Triggering re-analysis - scan_id: \(scanId)")
                
                // Show analyzing state immediately
                await MainActor.run {
                    self.isReanalyzingLocally = true
                }
                
                let updatedScan = try await webService.reanalyzeScan(scanId: scanId)
                
                await MainActor.run {
                    self.scan = updatedScan
                    self.isReanalyzingLocally = false // Reset local state as scan state takes over
                    
                    // If state became one that requires polling, restart polling
                    if updatedScan.state != "done" {
                        startPolling(scanId: scanId)
                    }
                }
            } catch {
                print("[ProductDetailView] ❌ Re-analysis failed: \(error)")
                await MainActor.run {
                    self.isReanalyzingLocally = false
                }
            }
        }
    }

    // MARK: - Fetch and Poll Logic

    private func fetchAndPollScan(scanId: String) async {
        do {
            // Initial fetch
            print("[ProductDetailView] 🔵 Fetching scan via API - scan_id: \(scanId)")
            let fetchedScan = try await webService.getScan(scanId: scanId)

            await MainActor.run {
                self.scan = fetchedScan
                // Update favorite state from fetched scan
                self.isFavorite = fetchedScan.is_favorited ?? false
                print("[ProductDetailView] ✅ Scan fetched - scan_id: \(scanId), state: \(fetchedScan.state), is_favorited: \(fetchedScan.is_favorited ?? false)")
            }

            // Start polling if scan is still processing or analyzing
            if fetchedScan.scan_type == "photo" || fetchedScan.scan_type == "barcode_plus_photo" {
                if fetchedScan.state != "done" {
                    print("[ProductDetailView] ⏳ Starting polling - scan_id: \(scanId), state: \(fetchedScan.state)")
                    startPolling(scanId: scanId)
                } else {
                    // Scan complete, increment count
                    print("[ProductDetailView] ✅ Scan is done - scan_id: \(scanId)")
                    await MainActor.run {
                        userPreferences.incrementScanCount()
                    }
                }
            }
        } catch {
            print("[ProductDetailView] ❌ Failed to fetch scan - scan_id: \(scanId), error: \(error)")
        }
    }

    private func startPolling(scanId: String) {
        // Cancel existing polling task
        pollingTask?.cancel()

        pollingTask = Task {
            var pollCount = 0
            let maxPolls = 30

            while pollCount < maxPolls {
                pollCount += 1

                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                    print("[ProductDetailView] 🔄 Poll #\(pollCount) - scan_id: \(scanId)")
                    let fetchedScan = try await webService.getScan(scanId: scanId)

                    await MainActor.run {
                        self.scan = fetchedScan
                    }

                    // Stop polling if scan is done
                    if fetchedScan.state == "done" {
                        print("[ProductDetailView] ✅ Scan done - scan_id: \(scanId), stopping polls")
                        await MainActor.run {
                            userPreferences.incrementScanCount()
                        }
                        break
                    }
                } catch is CancellationError {
                    print("[ProductDetailView] ⏹️ Polling cancelled - scan_id: \(scanId)")
                    break
                } catch {
                    print("[ProductDetailView] ❌ Poll error - scan_id: \(scanId), error: \(error)")
                }
            }

            if pollCount >= maxPolls {
                print("[ProductDetailView] ⏱️ Max polls reached - scan_id: \(scanId)")
            }
        }
    }
    
    // MARK: - Feedback Handling
    
    private func handleProductFeedback(voteType: String) {
        guard let scan = scan else { return }
        
        Task {
            do {
                let updatedScan: DTO.Scan
                
                // Check if user already voted with same value -> Toggle off (Update to "none")
                if let currentVote = scan.product_info_vote, currentVote.value == voteType {
                   updatedScan = try await webService.updateFeedback(feedbackId: currentVote.id, vote: "none")
                }
                // Check if user already voted but different value -> Update to new value
                else if let currentVote = scan.product_info_vote {
                    updatedScan = try await webService.updateFeedback(feedbackId: currentVote.id, vote: voteType)
                }
                // No existing vote -> Create new feedback
                else {
                    let request = DTO.FeedbackRequest(
                        target: "product_info",
                        vote: voteType,
                        scan_id: scan.id,
                        analysis_id: scan.analysis_id,
                        image_url: nil,
                        ingredient_name: nil,
                        comment: nil
                    )
                    updatedScan = try await webService.submitFeedback(request: request)
                }
                
                await MainActor.run {
                    self.scan = updatedScan
                }
            } catch {
                print("Error submitting feedback: \(error)")
            }
        }
    }
    
    private func handleIngredientFeedback(item: IngredientAlertItem, voteType: String) {
        guard let scan = scan, let rawName = item.rawIngredientName else { return }
        
        Task {
            do {
                let updatedScan: DTO.Scan
                
                // Check existing vote
                if let currentVote = item.vote, currentVote.value == voteType {
                     updatedScan = try await webService.updateFeedback(feedbackId: currentVote.id, vote: "none")
                } else if let currentVote = item.vote {
                     updatedScan = try await webService.updateFeedback(feedbackId: currentVote.id, vote: voteType)
                } else {
                    let request = DTO.FeedbackRequest(
                        target: "ingredient_analysis",
                        vote: voteType,
                        scan_id: scan.id,
                        analysis_id: scan.analysis_id,
                        image_url: nil,
                        ingredient_name: rawName,
                        comment: nil
                    )
                    updatedScan = try await webService.submitFeedback(request: request)
                }
                
                await MainActor.run {
                    self.scan = updatedScan
                }
            } catch {
                print("Error submitting ingredient feedback: \(error)")
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            
            Spacer()
            
            Text("Product Detail")
                .font(ManropeFont.semiBold.size(18))
                .foregroundStyle(.grayScale150)
            
            Spacer()
            
            Button {
                toggleFavorite()
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundStyle(isFavorite ? Color(hex: "#FF1100") : .grayScale150)
            }
            .disabled(scanId == nil && product == nil)  // Disable if no scan or product data
            
            // Re-analysis button (nearby heart icon)
            if resolvedIsStale {
                Button {
                    performReanalysis()
                } label: {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: "#FF8A00")) // Orange to indicate action needed/stale
                }
                .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
    
    // MARK: - Missing Ingredients View
    
    /// Shows when product has images/name but no ingredients
    private var missingIngredientsView: some View {
        VStack(spacing: 12) {
            Spacer()
                .frame(height: 20)
            
            // Bot Logo (black and white)
            Image("ingrediBot")
                .resizable()
                .scaledToFit()
                .frame(width: 117, height: 106)
                .saturation(0) // Grayscale effect
            
            // Title
            Text("Missing Ingredients")
                .font(NunitoFont.bold.size(20))
                .foregroundStyle(Color(hex: "#303030"))
                .multilineTextAlignment(.center)
            
            // Description
            Text("Add photos to help us analyze it.")
                .font(ManropeFont.medium.size(14))
                .foregroundStyle(Color(hex: "#949494"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            // Upload photos button
            Button {
                handleCameraButtonTap()
            } label: {
                GreenCapsule(title: "Upload photos", takeFullWidth: false)
            }
            .buttonStyle(.plain)
            .padding(.top, 40)
            
            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Gallery Helper Components
    
    /// Resolves ProductImage enum to actual SwiftUI Image view
    @ViewBuilder
    private func imageContent(for productImage: ProductImage) -> some View {
        switch productImage {
        case .local(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        case .api(let location):
            HeaderImage(imageLocation: location)
        }
    }
    
    /// Thumbnail view for a product image with selection styling
    @ViewBuilder
    private func thumbnailView(at index: Int) -> some View {
        let isSelected = selectedImageIndex == index

        Button {
            if !isPlaceholderMode {
                selectedImageIndex = index
            }
        } label: {
            imageContent(for: allImages[index])
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .opacity(isSelected ? 0.5 : 1.0)
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(
                            isSelected ? Color.primary600 : Color(hex: "#E3E3E3"),
                            lineWidth: 0.75
                        )
                )
        }
        .disabled(isPlaceholderMode)
    }
    
    /// Placeholder thumbnail for empty image slots
    private var placeholderThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11)
                .fill(Color(hex: "#F7F7F7"))
            Image("addimageiconsmall")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
        }
        .frame(width: 50, height: 50)
    }
    
    /// Green add camera button
    private var addCameraButton: some View {
        Button {
            handleCameraButtonTap()
        } label: {
            Image("addimageiconingreen")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .frame(width: 50, height: 50)
                .background(Color(hex: "#F6FCED"))
                .cornerRadius(8)
        }
        .disabled(isPlaceholderMode)
    }

    private func handleCameraButtonTap() {
        switch presentationSource {
        case .homeView:
            // Open camera full screen on top of ProductDetails
            isCameraPresentedFromDetail = true
        case .cameraView:
            // Dismiss ProductDetails and return to camera with this scanId
            if let scanId = scanId {
                onRequestCameraWithScan?(scanId)
            }
            dismiss()
        }
    }
    
    /// Main gallery image display (large preview)
    private var mainGalleryImage: some View {
        Button {
            if !isPlaceholderMode {
                isImageViewerPresented = true
            }
        } label: {
            imageContent(for: allImages[selectedImageIndex])
                .frame(
                    width: UIScreen.main.bounds.width * 0.704,
                    height: UIScreen.main.bounds.height * 0.234
                )
                .cornerRadius(16)
                .clipped()
                .background(in: RoundedRectangle(cornerRadius: 24))
                .shadow(color: Color(hex: "#CECECE").opacity(0.25), radius: 12)
        }
        .buttonStyle(.plain)
    }
    
    /// Empty state placeholder for main gallery
    private var emptyStateGalleryImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color(hex: "#CECECE").opacity(0.25), radius: 12)
            Image("addimageiconlarge")
                .resizable()
                .scaledToFit()
                .frame(width: 85, height: 79)
        }
        .frame(
            width: UIScreen.main.bounds.width * 0.704,
            height: UIScreen.main.bounds.height * 0.234
        )
    }
    
    /// Side panel with thumbnails
    private var thumbnailSidePanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                addCameraButton
                
                // Determine which indices to show
                let indices = allImages.count <= 2 ? Array(0..<3) : Array(allImages.indices)
                
                ForEach(indices, id: \.self) { index in
                    if index < allImages.count {
                        thumbnailView(at: index)
                    } else {
                        placeholderThumbnail
                    }
                }
            }
        }
        .frame(width: 60, height: 196)
    }
    
    /// Empty state side panel (all placeholders)
    private var emptyStateSidePanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                addCameraButton
                
                ForEach(0..<3, id: \.self) { _ in
                    placeholderThumbnail
                }
            }
        }
        .frame(width: 60, height: 196)
    }
    
    // MARK: - Product Gallery
    
    private var productGallery: some View {
        HStack(spacing: 12) {
            if !allImages.isEmpty {
                mainGalleryImage
                thumbnailSidePanel
            } else {
                emptyStateGalleryImage
                emptyStateSidePanel
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private var productInformation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(resolvedBrand)
                .font(ManropeFont.regular.size(14))
                .foregroundStyle(.grayScale100)
            
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resolvedName)
                        .font(NunitoFont.bold.size(20))
                        .foregroundStyle(.grayScale150)
              
                    // Only show resolvedDetails if it's not empty (API doesn't provide this field)
                    if !resolvedDetails.isEmpty {
                        Text(resolvedDetails)
                            .font(ManropeFont.medium.size(14))
                            .foregroundStyle(.grayScale100)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 16) {
                    HStack(spacing: 4) {
                        StatusDotView(status: resolvedStatus)
                        
                        Text(resolvedStatus.title)
                            .font(NunitoFont.bold.size(14))
                            .foregroundStyle(resolvedStatus.color)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(resolvedStatus.badgeBackground, in: Capsule())
                    
                    HStack(spacing: 12) {
                        Button {
                            handleProductFeedback(voteType: "up")
                        } label: {
                            let isSelected = scan?.product_info_vote?.value == "up"
                            let color = isSelected ? Color(hex: "#FBCB7F") : Color.grayScale100
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(color, lineWidth: 0.5)
                                Image(isSelected ? "thumbsup.fill" : "thumbsup")
                                    .renderingMode(isSelected ? .original : .template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 18)
                                    .foregroundStyle(isSelected ? Color.green : color)
                            }
                            .frame(width: 32, height: 28)
                        }
                        .buttonStyle(.plain)

                        Button {
                            handleProductFeedback(voteType: "down")
                        } label: {
                            let isSelected = scan?.product_info_vote?.value == "down"
                            let color = isSelected ? Color(hex: "#FF594E") : Color.grayScale100
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(color, lineWidth: 0.5)
                                Image(isSelected ? "thumbsdown.fill" : "thumbsdown")
                                    .renderingMode(isSelected ? .original : .template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 18)
                                    .foregroundStyle(isSelected ? Color.red : color)
                            }
                            .frame(width: 32, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private var dietaryTagsRow: some View {
        if !dietaryTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dietaryTags, id: \.claim) { tag in
                        DietaryTagView(tag: tag)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
    }
}

// MARK: - ScanCameraView Wrapper

/// Wrapper to initialize ScanCameraView with specific mode and scanId
struct ScanCameraViewWrapper: View {
    let initialScanId: String?
    let initialMode: CameraMode

    var body: some View {
        ScanCameraViewWithInitialState(
            initialScanId: initialScanId,
            initialMode: initialMode
        )
    }
}

#if DEBUG
// Sample product with ingredients for preview
private let sampleProductWithIngredients = DTO.Product(
    barcode: "1234567890",
    brand: "Sample Brand",
    name: "Sample Product",
    ingredients: [
        DTO.Ingredient(name: "Water", vegan: true, vegetarian: true, ingredients: []),
        DTO.Ingredient(name: "Sugar", vegan: true, vegetarian: true, ingredients: []),
        DTO.Ingredient(name: "Salt", vegan: true, vegetarian: true, ingredients: [])
    ],
    images: [],
    claims: ["Vegan", "No gluten"]
)

// Sample product WITHOUT ingredients for preview (triggers Missing Ingredients UI)
private let sampleProductMissingIngredients = DTO.Product(
    barcode: "1234567890",
    brand: "Sample Brand",
    name: "Sample Product Without Ingredients",
    ingredients: [],
    images: [],
    claims: []
)

#Preview("Normal Mode") {
    ProductDetailView(
        product: sampleProductWithIngredients,
        isPlaceholderMode: false
    )
    .environment(WebService())
    .environment(UserPreferences())
    .environment(AppNavigationCoordinator())
}

#Preview("Missing Ingredients") {
    ProductDetailView(
        product: sampleProductMissingIngredients,
        isPlaceholderMode: false
    )
    .environment(WebService())
    .environment(UserPreferences())
    .environment(AppNavigationCoordinator())
}

#Preview("Placeholder Mode") {
    ProductDetailView(isPlaceholderMode: true)
        .environment(WebService())
        .environment(UserPreferences())
        .environment(AppNavigationCoordinator())
}
#endif

// MARK: - Product Match Status

enum ProductMatchStatus {
    case matched
    case uncertain
    case unmatched
    case unknown
    case analyzing  // Analysis in progress

    var title: String {
        switch self {
        case .matched: return "Matched"
        case .uncertain: return "Uncertain"
        case .unmatched: return "Unmatched"
        case .unknown: return "Unknown"
        case .analyzing: return "Analyzing"
        }
    }

    var color: Color {
        switch self {
        case .matched: return Color(hex: "#5A9C19")
        case .uncertain: return Color(hex: "#E9A600")
        case .unmatched: return Color(hex: "#FF4E50")
        case .unknown: return Color.grayScale100
        case .analyzing: return Color(hex: "#007AFF")  // Blue for analyzing
        }
    }

    var badgeBackground: Color {
        switch self {
        case .matched: return Color(hex: "#EAF6D9")
        case .uncertain: return Color(hex: "#FFF5DA")
        case .unmatched: return Color(hex: "#FFE3E2")
        case .unknown: return Color.grayScale40
        case .analyzing: return Color(hex: "#E3F2FF")  // Light blue for analyzing
        }
    }

    var alertTitle: String {
        switch self {
        case .matched: return "Great Match"
        case .uncertain: return "Partially Compatible"
        case .unmatched: return "Ingredients Alerts"
        case .unknown: return "Status Unknown"
        case .analyzing: return "Analyzing Product"
        }
    }

    var alertCardBackground: Color {
        switch self {
        case .matched: return Color(hex: "#F3FAE7")
        case .uncertain: return Color(hex: "#FFF8E8")
        case .unmatched: return Color(hex: "#FFEAEA")
        case .unknown: return Color.grayScale40
        case .analyzing: return Color(hex: "#F0F8FF")  // Light blue for analyzing
        }
    }

    var sectionBackground: Color {
        badgeBackground
    }
}


