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
    case pushNavigation  // Used when navigating via AppRoute (Single Root NavigationStack)
}

struct ProductDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WebService.self) private var webService
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(ScanHistoryStore.self) private var scanHistoryStore
    @Environment(AppState.self) private var appState: AppState?  // Optional - for push navigation
    @Environment(AppNavigationCoordinator.self) private var coordinator: AppNavigationCoordinator?
    @Environment(FoodNotesStore.self) private var foodNotesStore

    @State private var isFavorite = false
    @AppStorage("ingredientsSectionExpanded") private var isIngredientsExpanded = true  // Default: expanded, persists user choice
    @State private var isIngredientsAlertExpanded = false
    @State private var selectedImageIndex = 0
    @State private var activeIngredientHighlight: IngredientHighlight?
    @State private var isImageViewerPresented = false
    @State private var isReanalyzingLocally = false  // Temporary state to show analyzing UI immediately
    @State private var reanalysisRotation: Double = 0  // Rotation for sync icon animation

    // Real-time scan observation (new approach)
    var scanId: String? = nil  // If provided, view will fetch/poll for scan updates
    var initialScan: DTO.Scan? = nil  // Initial scan data (if from cache/SSE)
    @State private var scan: DTO.Scan? = nil  // Current scan data (updates via polling)
    @State private var pollingTask: Task<Void, Never>? = nil

    // Feedback loading states (show spinner on thumb buttons while API responds)
    @State private var isProductFeedbackLoading = false
    @State private var loadingIngredientName: String? = nil  // Track which ingredient is loading
    @State private var loadingImageUrl: String? = nil  // Track which image is loading

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
        case api(DTO.ImageLocationInfo, vote: DTO.Vote?)

        var id: String {
            switch self {
            case .local(let image):
                return "local_\(image.hashValue)"
            case .api(let location, _):
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

        // Add API images
        if let scan = scan, !scan.images.isEmpty {
             // Prefer scan images as they contain vote info
             if localImages == nil || localImages?.isEmpty == true {
                 for scanImage in scan.images {
                     switch scanImage {
                     case .inventory(let img):
                         if let url = URL(string: img.url) {
                             images.append(.api(.url(url), vote: img.vote))
                         }
                     case .user(let img):
                         if img.status == "processed", let storagePath = img.storage_path {
                             images.append(.api(.scanImagePath(storagePath), vote: nil))
                         }
                     }
                 }
             }
        } else if let product = resolvedProduct, !product.images.isEmpty {
            // Fallback for legacy mode
            if localImages == nil || localImages?.isEmpty == true {
                images.append(contentsOf: product.images.map { ProductImage.api($0, vote: nil) })
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

    // Check if product exists but has no name, no brand, and no ingredients (not in our database)
    private var hasEmptyProductDetails: Bool {
        guard let product = resolvedProduct else { return false }
        let hasNoName = product.name == nil || product.name?.isEmpty == true
        let hasNoBrand = product.brand == nil || product.brand?.isEmpty == true
        let hasNoIngredients = product.ingredients.isEmpty
        return hasNoName && hasNoBrand && hasNoIngredients && !isPlaceholderMode && !isAnalyzing
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
        // If user has no food notes at all, always show a neutral "no preferences"
        // status regardless of scan type/state, so the header never flips to
        // "Unknown" or "Analyzing" while preferences are empty.
        if hasNoFoodNotes {
            if let scan = scan {
                print("[ProductDetailView] 🟦 noPreferences (hasNoFoodNotes=true) for scan_id=\(scan.id)")
            }
            return .noPreferences
        }

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
        case .noPreferences:
            return .noPreferences
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

    private var hasNoFoodNotes: Bool {
        if foodNotesStore.canvasPreferences.sections.isEmpty {
            return true
        }

        if let summary = foodNotesStore.foodNotesSummary {
            let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "No Food Notes yet." {
                return true
            }
            return false
        }

        return false
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
        
        // Create highlights from resolvedIngredientRecommendations (handles both scan and legacy modes)
        var highlights: [IngredientHighlight] = []
        if let recommendations = resolvedIngredientRecommendations {
            for recommendation in recommendations {
                // Only create highlights for flagged ingredients
                if recommendation.safetyRecommendation != .safe {
                    // Use appropriate color based on safety recommendation
                    let highlightColor: Color = recommendation.safetyRecommendation == .definitelyUnsafe
                        ? .fail100  // Red for unmatched
                        : .warning100  // Yellow for uncertain (maybeUnsafe)

                    highlights.append(IngredientHighlight(
                        phrase: recommendation.ingredientName,
                        reason: recommendation.reasoning,
                        color: highlightColor
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
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if hasEmptyProductDetails {
                        // Empty product state: no gallery, no product info — just centered empty state
                        emptyProductDetailsView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 60)
                    } else {
                        // Gallery section - never redacted, shows placeholder images
                        productGallery
                            .unredacted()
                            .padding(.top, 16)

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
                                        },
                                        productVote: scan?.product_info_vote,
                                        onProductFeedback: { voteType in
                                            handleProductFeedback(voteType: voteType)
                                        },
                                        isProductFeedbackLoading: isProductFeedbackLoading,
                                        loadingIngredientName: loadingIngredientName
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
        }
        .background(Color(hex: "#FAFAFA"))  // Lighter background for Product Details
        .overlay(alignment: .bottom) {
            // Ingredient tooltip overlay - shown at ProductDetailView level for proper positioning
            if let highlight = activeIngredientHighlight {
                ZStack(alignment: .bottom) {
                    // Dismiss backdrop
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activeIngredientHighlight = nil
                            }
                        }

                    // Tooltip card
                    VStack(alignment: .leading, spacing: 6) {
                        Text(highlight.phrase)
                            .font(NunitoFont.bold.size(14))
                            .foregroundStyle(.grayScale150)

                        Text(highlight.reason)
                            .font(ManropeFont.regular.size(13))
                            .foregroundStyle(.grayScale120)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: -8)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: activeIngredientHighlight)
        .navigationTitle(resolvedBrand.isEmpty ? "Product Detail" : resolvedBrand)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "#FAFAFA"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            // Back button (only show when presented from camera view)
            if presentationSource == .cameraView {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(ManropeFont.medium.size(16))
                        }
                        .foregroundStyle(.grayScale150)
                        .padding(.leading, 4)
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Re-analysis button (when stale or reanalyzing)
                    if resolvedIsStale || isReanalyzingLocally {
                        Button {
                            if !isReanalyzingLocally {
                                performReanalysis()
                            }
                        } label: {
                            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(isReanalyzingLocally ? Color.grayScale50 : Color(hex: "#FF8A00"))
                                .rotationEffect(.degrees(reanalysisRotation))
                        }
                        .disabled(isReanalyzingLocally)
                        .onChange(of: isReanalyzingLocally) { _, isReanalyzing in
                            if isReanalyzing {
                                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                    reanalysisRotation = 360
                                }
                            } else {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    reanalysisRotation = 0
                                }
                            }
                        }
                    }

                    // Favorite button
                    Button {
                        toggleFavorite()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 20))
                            .foregroundStyle(isFavorite ? Color(hex: "#FF1100") : .grayScale150)
                    }
                    .disabled(scanId == nil && product == nil)
                }
                .padding(.trailing, 4)
            }
        }
        .onChange(of: isIngredientsExpanded) { _, expanded in
            if !expanded {
                activeIngredientHighlight = nil
            }
        }
        .fullScreenCover(isPresented: $isImageViewerPresented) {
            FullScreenImageViewer(
                images: allImages,
                selectedIndex: $selectedImageIndex,
                onFeedback: { url, vote in
                    handleImageFeedback(imageUrl: url, voteType: vote)
                },
                loadingImageUrl: loadingImageUrl
            )
        }
        .task(id: scanId) {
            // If scanId is provided, fetch and poll for scan updates
            guard let scanId = scanId, !scanId.isEmpty else { return }

            // If initialScan is provided, use it directly
            if let initialScan = initialScan {
                print("[ProductDetailView] 📦 Using initialScan - scan_id: \(scanId), state: \(initialScan.state)")
                await MainActor.run {
                    self.scan = initialScan
                }

                // If scan is still processing/analyzing, start polling even with initialScan
                // This ensures ProductDetailView stays in sync when opened during analysis
                if initialScan.state != "done" {
                    print("[ProductDetailView] ⏳ initialScan not done, starting polling - scan_id: \(scanId), state: \(initialScan.state)")
                    await fetchAndPollScan(scanId: scanId)
                    return
                }

                // If barcode scan is done, no polling needed - SSE handles updates
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
        .onAppear { setDisplayedScanContext() }
        .onDisappear {
            // Cancel polling when view disappears
            pollingTask?.cancel()
            pollingTask = nil

            // Clear displayed scan context
            appState?.displayedScanId = nil
            appState?.displayedAnalysisId = nil
        }
    }

    // MARK: - Displayed Scan Context (for AIBot FAB)

    private func setDisplayedScanContext() {
        appState?.displayedScanId = scanId
        appState?.displayedAnalysisId = scan?.analysis_result?.id ?? scan?.analysis_id
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
                        analysis_id: currentScan.analysis_result?.id ?? currentScan.analysis_id
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
        guard let currentScan = scan else { return }
        guard !isProductFeedbackLoading else { return }  // Prevent double-tap

        // Validate required fields for product_info feedback
        guard !currentScan.id.isEmpty else {
            Log.error("ProductDetailView", "Cannot submit product feedback: scan_id is missing")
            return
        }

        // Start loading
        isProductFeedbackLoading = true

        // 1. Calculate optimistic new vote
        let oldVote = currentScan.product_info_vote

        var optimisticVote: DTO.Vote?

        if let currentVote = currentScan.product_info_vote, currentVote.value == voteType {
             // Toggle off
             optimisticVote = nil
        } else {
             // Set new vote
             optimisticVote = DTO.Vote(id: oldVote?.id ?? "optimistic-\(UUID().uuidString)", value: voteType)
        }

        // 2. Apply optimistic state
        var optimisticScan = currentScan
        optimisticScan.product_info_vote = optimisticVote
        self.scan = optimisticScan
        // Sync to central store
        scanHistoryStore.upsertScan(optimisticScan)

        Task {
            defer {
                Task { @MainActor in
                    isProductFeedbackLoading = false
                }
            }

            do {
                let updatedScan: DTO.Scan

                // 3. Perform network request
                if let currentVote = currentScan.product_info_vote, currentVote.value == voteType {
                   updatedScan = try await webService.updateFeedback(feedbackId: currentVote.id, vote: "none")
                }
                else if let currentVote = currentScan.product_info_vote {
                    updatedScan = try await webService.updateFeedback(feedbackId: currentVote.id, vote: voteType)
                }
                else {
                    let request = DTO.FeedbackRequest(
                        target: "product_info",
                        vote: voteType,
                        scan_id: currentScan.id,
                        analysis_id: nil,
                        image_url: nil,
                        ingredient_name: nil,
                        comment: nil
                    )
                    updatedScan = try await webService.submitFeedback(request: request)
                }

                // 4. Confirm state with server response (replaces optimistic ID with real one)
                await MainActor.run {
                    self.scan = updatedScan
                    // Sync confirmed state to central store
                    scanHistoryStore.upsertScan(updatedScan)

                    // Show feedback prompt bubble only for NEW down votes (not when resetting)
                    let wasToggleOff = currentScan.product_info_vote?.value == voteType
                    if voteType == "down" && !wasToggleOff, let feedbackId = updatedScan.product_info_vote?.id {
                        coordinator?.showFeedbackPrompt(feedbackId: feedbackId)
                    }
                }
            } catch {
                Log.error("ProductDetailView", "Error submitting product feedback: \(error.localizedDescription)")
                // 5. Revert on error
                await MainActor.run {
                    self.scan = currentScan
                    // Revert in central store
                    scanHistoryStore.upsertScan(currentScan)
                }
            }
        }
    }
    
    private func handleIngredientFeedback(item: IngredientAlertItem, voteType: String) {
        guard let currentScan = scan, let rawName = item.rawIngredientName else { return }
        guard loadingIngredientName == nil else { return }  // Prevent double-tap

        // Validate required fields for flagged_ingredient feedback
        guard !rawName.isEmpty else {
            Log.error("ProductDetailView", "Cannot submit ingredient feedback: ingredient_name is empty")
            return
        }

        // Check if we have an existing vote - if so, we can update without analysis_id
        let hasExistingVote = item.vote != nil

        // For new feedback, analysis_id is required per API spec
        // Get analysis_id from analysis_result.id (primary source) or fallback to top-level analysis_id
        let analysisId = currentScan.analysis_result?.id ?? currentScan.analysis_id
        
        guard hasExistingVote || analysisId != nil || currentScan.analysis_result != nil else {
            Log.error("ProductDetailView", "Cannot submit ingredient feedback: analysis_id is missing and no existing vote to update")
            return
        }

        // Start loading for this ingredient
        loadingIngredientName = rawName

        // 1. Calculate optimistic new vote
        let oldVote = item.vote

        var optimisticVote: DTO.Vote?
        if let currentVote = item.vote, currentVote.value == voteType {
             optimisticVote = nil // Toggle off
        } else {
             optimisticVote = DTO.Vote(id: oldVote?.id ?? "optimistic-\(UUID().uuidString)", value: voteType)
        }

        // 2. Apply optimistic state locally by modifying the scan's analysis result
        // We need to find the specific ingredient in the scan and update its vote
        var optimisticScan = currentScan
        if var analysisResult = optimisticScan.analysis_result {
            var ingredientAnalysis = analysisResult.ingredient_analysis

            // Find index of ingredient matching rawName
            if let index = ingredientAnalysis.firstIndex(where: { $0.ingredient == rawName }) {
                var updatedIngredient = ingredientAnalysis[index]
                updatedIngredient.vote = optimisticVote
                ingredientAnalysis[index] = updatedIngredient

                // Assign back nested structs
                analysisResult.ingredient_analysis = ingredientAnalysis
                optimisticScan.analysis_result = analysisResult

                // Update state
                self.scan = optimisticScan
                // Sync to central store
                scanHistoryStore.upsertScan(optimisticScan)
            }
        }

        Task {
            defer {
                Task { @MainActor in
                    loadingIngredientName = nil
                }
            }
            do {
                let updatedScan: DTO.Scan
                
                // 3. Perform network request
                if let currentVote = item.vote, currentVote.value == voteType {
                     updatedScan = try await webService.updateFeedback(feedbackId: currentVote.id, vote: "none")
                } else if let currentVote = item.vote {
                     updatedScan = try await webService.updateFeedback(feedbackId: currentVote.id, vote: voteType)
                } else {
                    // For new feedback, analysis_id is required per API spec
                    // Get analysis_id from analysis_result.id (primary source) or fallback to top-level analysis_id
                    let finalAnalysisId = currentScan.analysis_result?.id ?? analysisId
                    guard let finalAnalysisId = finalAnalysisId, !finalAnalysisId.isEmpty else {
                        Log.error("ProductDetailView", "Cannot create new ingredient feedback: analysis_id is required but missing")
                        // Revert optimistic update
                        await MainActor.run {
                            self.scan = currentScan
                            scanHistoryStore.upsertScan(currentScan)
                        }
                        return
                    }
                    
                    let request = DTO.FeedbackRequest(
                        target: "flagged_ingredient",
                        vote: voteType,
                        scan_id: currentScan.id,
                        analysis_id: finalAnalysisId,
                        image_url: nil,
                        ingredient_name: rawName,
                        comment: nil
                    )
                    updatedScan = try await webService.submitFeedback(request: request)
                }
                
                // 4. Confirm state
                await MainActor.run {
                    self.scan = updatedScan
                    // Sync confirmed state to central store
                    scanHistoryStore.upsertScan(updatedScan)

                    // Show feedback prompt bubble only for NEW down votes (not when resetting)
                    let wasToggleOff = item.vote?.value == voteType
                    if voteType == "down" && !wasToggleOff {
                        if let feedbackId = updatedScan.analysis_result?.ingredient_analysis
                            .first(where: { $0.ingredient == rawName })?.vote?.id {
                            coordinator?.showFeedbackPrompt(feedbackId: feedbackId)
                        }
                    }
                }
            } catch {
                Log.error("ProductDetailView", "Error submitting ingredient feedback: \(error.localizedDescription)")
                // 5. Revert
                await MainActor.run {
                    self.scan = currentScan
                    // Revert in central store
                    scanHistoryStore.upsertScan(currentScan)
                }
            }
        }
    }
    
    private func handleImageFeedback(imageUrl: String, voteType: String) {
        guard let currentScan = scan else { return }
        guard loadingImageUrl == nil else { return }  // Prevent double-tap

        // Validate required fields for product_image feedback
        guard !currentScan.id.isEmpty else {
            Log.error("ProductDetailView", "Cannot submit image feedback: scan_id is missing")
            return
        }

        guard !imageUrl.isEmpty else {
            Log.error("ProductDetailView", "Cannot submit image feedback: image_url is empty")
            return
        }

        // Start loading for this image
        loadingImageUrl = imageUrl

        // 1. Find the image and current vote
        guard let imageIndex = currentScan.images.firstIndex(where: { img in
            switch img {
            case .inventory(let i): return i.url == imageUrl
            default: return false
            }
        }) else {
            Log.error("ProductDetailView", "Cannot submit image feedback: image not found in scan")
            return
        }
        
        var targetImage = currentScan.images[imageIndex]
        var oldVote: DTO.Vote?
        if case .inventory(let invImg) = targetImage {
            oldVote = invImg.vote
        }
        
        // 2. Calculate optimistic vote
        var optimisticVote: DTO.Vote?
        if let currentVote = oldVote, currentVote.value == voteType {
             optimisticVote = nil // Toggle off
        } else {
             optimisticVote = DTO.Vote(id: oldVote?.id ?? "optimistic-\(UUID().uuidString)", value: voteType)
        }
        
        // 3. Apply optimistic state
        var optimisticScan = currentScan
        // Update the specific image
        if case .inventory(var invImg) = targetImage {
            invImg.vote = optimisticVote
            targetImage = .inventory(invImg)
            optimisticScan.images[imageIndex] = targetImage
            
            self.scan = optimisticScan
            scanHistoryStore.upsertScan(optimisticScan)
        }
        
        Task {
            defer {
                Task { @MainActor in
                    loadingImageUrl = nil
                }
            }

            do {
                let updatedScan: DTO.Scan

                // 4. Network request
                if let currentVote = oldVote, currentVote.value == voteType {
                     updatedScan = try await webService.updateFeedback(feedbackId: currentVote.id, vote: "none")
                } else if let currentVote = oldVote {
                     updatedScan = try await webService.updateFeedback(feedbackId: currentVote.id, vote: voteType)
                } else {
                    let request = DTO.FeedbackRequest(
                        target: "product_image",
                        vote: voteType,
                        scan_id: currentScan.id,
                        analysis_id: nil,
                        image_url: imageUrl,
                        ingredient_name: nil,
                        comment: nil
                    )
                    updatedScan = try await webService.submitFeedback(request: request)
                }

                // 5. Confirm state
                await MainActor.run {
                    self.scan = updatedScan
                    scanHistoryStore.upsertScan(updatedScan)

                    // Show feedback prompt bubble only for NEW down votes (not when resetting)
                    let wasToggleOff = oldVote?.value == voteType
                    if voteType == "down" && !wasToggleOff {
                        if let feedbackId = updatedScan.images.lazy.compactMap({ img -> String? in
                            switch img {
                            case .inventory(let i) where i.url == imageUrl: return i.vote?.id
                            default: return nil
                            }
                        }).first {
                            coordinator?.showFeedbackPrompt(feedbackId: feedbackId)
                        }
                    }
                }
            } catch {
                Log.error("ProductDetailView", "Error submitting image feedback: \(error.localizedDescription)")
                await MainActor.run {
                    self.scan = currentScan
                    scanHistoryStore.upsertScan(currentScan)
                }
            }
        }
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

    // MARK: - Empty Product Details View

    /// Shows when product exists but has no name, no brand, and no ingredients (not in our database)
    private var emptyProductDetailsView: some View {
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
            Text("Product Not Found")
                .font(NunitoFont.bold.size(20))
                .foregroundStyle(Color(hex: "#303030"))
                .multilineTextAlignment(.center)

            // Description
            Text("We couldn't find this product. Capture photos from different angles so we can analyze it for you.")
                .font(ManropeFont.medium.size(14))
                .foregroundStyle(Color(hex: "#949494"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // Capture photos button
            Button {
                handleCameraButtonTap()
            } label: {
                GreenCapsule(title: "Capture photos", takeFullWidth: false)
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
        case .api(let location, _):
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
            // From HomeView, navigate to camera (no existing camera in stack)
            if let appState = appState {
                appState.navigate(to: .scanCamera(initialMode: .photo, initialScanId: scanId))
            }
        case .pushNavigation:
            // From push navigation - check if camera is actually in the stack
            if let appState = appState {
                if appState.hasCameraInStack {
                    // Camera exists in stack, pop back to it
                    appState.scrollToScanId = scanId
                    appState.navigateBack()
                } else {
                    // No camera in stack (came from HomeView/Recent Scans), push new camera
                    appState.navigate(to: .scanCamera(initialMode: .photo, initialScanId: scanId))
                }
            }
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
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resolvedName)
                        .font(NunitoFont.bold.size(20))
                        .foregroundStyle(.grayScale150)
                        .lineLimit(2)
              
                    // Only show resolvedDetails if it's not empty (API doesn't provide this field)
                    if !resolvedDetails.isEmpty {
                        Text(resolvedDetails)
                            .font(ManropeFont.medium.size(14))
                            .foregroundStyle(.grayScale100)
                    }
                }
                
//                if !(resolvedStatus == .noPreferences) {
                    Spacer()
//                }
                
                
                if resolvedStatus == .noPreferences {
                    NotPersonalized()
                        .layoutPriority(1)
                } else {
                    HStack(spacing: 4) {
                        StatusDotView(status: resolvedStatus)
                        
                        Text(resolvedStatus.title)
                            .font(NunitoFont.bold.size(14))
                            .foregroundStyle(resolvedStatus.color)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(resolvedStatus.badgeBackground, in: Capsule())
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
            initialMode: initialMode,
            presentationSource: .productDetailView
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
    case noPreferences

    var title: String {
        switch self {
        case .matched: return "Matched"
        case .uncertain: return "Uncertain"
        case .unmatched: return "Unmatched"
        case .unknown: return "Unknown"
        case .analyzing: return "Analyzing"
        case .noPreferences: return "Not Personalized"
        }
    }

    var color: Color {
        switch self {
        case .matched: return Color(hex: "#5A9C19")
        case .uncertain: return Color(hex: "#E9A600")
        case .unmatched: return Color(hex: "#FF4E50")
        case .unknown: return Color.grayScale100
        case .analyzing: return Color(hex: "#007AFF")  // Blue for analyzing
        case .noPreferences: return Color.grayScale100
        }
    }

    var badgeBackground: Color {
        switch self {
        case .matched: return Color(hex: "#EAF6D9")
        case .uncertain: return Color(hex: "#FFF5DA")
        case .unmatched: return Color(hex: "#FFE3E2")
        case .unknown: return Color.grayScale40
        case .analyzing: return Color(hex: "#E3F2FF")  // Light blue for analyzing
        case .noPreferences: return Color.grayScale40
        }
    }

    var alertTitle: String {
        switch self {
        case .matched: return "Great Match"
        case .uncertain: return "Partially Compatible"
        case .unmatched: return "Ingredients Alerts"
        case .unknown: return "Status Unknown"
        case .analyzing: return "Analyzing Product"
        case .noPreferences: return "Not Personalized"
        }
    }

    var alertCardBackground: Color {
        switch self {
        case .matched: return Color(hex: "#F3FAE7")
        case .uncertain: return Color(hex: "#FFF8E8")
        case .unmatched: return Color(hex: "#FFEAEA")
        case .unknown: return Color.grayScale40
        case .analyzing: return Color(hex: "#F0F8FF")  // Light blue for analyzing
        case .noPreferences: return Color.grayScale40
        }
    }

    var sectionBackground: Color {
        badgeBackground
    }
}


