//
//  ProductDetailView.swift
//  IngrediCheckPreview
//
//  Created on 18/11/25.
//

import SwiftUI

struct ProductDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WebService.self) private var webService
    @Environment(UserPreferences.self) private var userPreferences

    @State private var isFavorite = false
    @State private var isIngredientsExpanded = false
    @State private var isIngredientsAlertExpanded = false
    @State private var selectedImageIndex = 0
    @State private var activeIngredientHighlight: IngredientHighlight?
    @State private var thumbSelection: ThumbSelection? = nil
    @State private var isCameraPresentedFromDetail = false

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

    // Check if analysis is in progress
    private var isAnalyzing: Bool {
        scan?.state == "analyzing" || scan?.state == "processing_images"
    }

    // Combined images: local images (if available) take priority over API images
    // This ensures photo mode shows the user's captured images
    private enum ProductImage: Identifiable {
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

    // Dietary tags from product claims
    private var dietaryTags: [DietaryTag] {
        guard let claims = resolvedProduct?.claims, !claims.isEmpty else {
            return []
        }

        // Convert claims to DietaryTag objects
        return claims.map { claim in
            DietaryTag(name: claim, icon: "white-rounded-checkmark")
        }
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
                
                return IngredientAlertItem(
                    name: recommendation.ingredientName,
                    detail: recommendation.reasoning,
                    status: status,
                    memberIdentifiers: recommendation.memberIdentifiers  // Use memberIdentifiers array
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                productGallery
                productInformation
                dietaryTagsRow
                
                if !resolvedIngredientAlertItems.isEmpty {
                    IngredientsAlertCard(
                        isExpanded: $isIngredientsAlertExpanded,
                        items: resolvedIngredientAlertItems,
                        status: resolvedStatus,
                        overallAnalysis: resolvedOverallAnalysis,
                        ingredientRecommendations: resolvedIngredientRecommendations
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
        .background(Color(hex: "FFFFFF"))
        .navigationBarBackButtonHidden(true)
        .redacted(reason: isPlaceholderMode ? .placeholder : [])
        .onChange(of: isIngredientsExpanded) { _, expanded in
            if !expanded {
                activeIngredientHighlight = nil
            }
        }
        .fullScreenCover(isPresented: $isCameraPresentedFromDetail) {
            CameraScreen()
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
                    print("[ProductDetailView] 🔄 Updated scan from initialScan change - scan_id: \(scanId), state: \(initialScan.state)")
                }
            }
        }
        .onDisappear {
            // Cancel polling when view disappears
            pollingTask?.cancel()
            pollingTask = nil
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
                print("[ProductDetailView] ✅ Scan fetched - scan_id: \(scanId), state: \(fetchedScan.state)")
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

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.black)
            }
            
            Spacer()
            
            Text("Product Detail")
                .font(ManropeFont.semiBold.size(18))
                .foregroundStyle(.grayScale150)
            
            Spacer()
            
            Button {
                isFavorite.toggle()
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundStyle(isFavorite ? Color(hex: "#FF1100") : .grayScale150)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
    
    private var productGallery: some View {
        HStack(spacing: 12) {
            if !allImages.isEmpty {
                // Display selected image (local or API)
                Group {
                    switch allImages[selectedImageIndex] {
                    case .local(let image):
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .api(let location):
                        HeaderImage(imageLocation: location)
                    }
                }
                .frame(
                    width: UIScreen.main.bounds.width * 0.704,
                    height: UIScreen.main.bounds.height * 0.234
                )
                .cornerRadius(16)
                    .clipped()
                    .background(in: RoundedRectangle(cornerRadius: 24))
                    .shadow(color: Color(hex: "#CECECE").opacity(0.25), radius: 12)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        Button {
                            isCameraPresentedFromDetail = true
                        } label: {
                            HStack {
                                Image("addimageiconingreen")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                            }
                            .frame(width: 50, height: 50)
                                .background(Color(hex: "#F6FCED"))
                                .cornerRadius(8)
                        }
                        .disabled(isPlaceholderMode)

                        if allImages.count <= 2 {
                            // Up to three slots: real images first (if any), then placeholder(s)
                            ForEach(0..<3, id: \.self) { index in
                                if index < allImages.count {
                                    Button {
                                        if !isPlaceholderMode {
                                            selectedImageIndex = index
                                        }
                                    } label: {
                                        Group {
                                            switch allImages[index] {
                                            case .local(let image):
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            case .api(let location):
                                                HeaderImage(imageLocation: location)
                                            }
                                        }
                                        .frame(width: 50, height: 50)
                                        .clipped()
                                        .opacity(selectedImageIndex == index ? 0.5 : 1.0)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 11)
                                                .stroke(
                                                    selectedImageIndex == index ? Color.primary600 : Color(hex: "#E3E3E3"),
                                                    lineWidth: 2
                                                )
                                        )
                                    }
                                    .disabled(isPlaceholderMode)
                                } else {
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
                            }
                        } else {
                            // Multiple images: show all as scrollable thumbnails
                            ForEach(allImages.indices, id: \.self) { index in
                                Button {
                                    if !isPlaceholderMode {
                                        selectedImageIndex = index
                                    }
                                } label: {
                                    Group {
                                        switch allImages[index] {
                                        case .local(let image):
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        case .api(let location):
                                            HeaderImage(imageLocation: location)
                                        }
                                    }
                                    .frame(width: 50, height: 50)
                                    .clipped()
                                    .opacity(selectedImageIndex == index ? 0.5 : 1.0)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11)
                                            .stroke(
                                                selectedImageIndex == index ? Color.primary600 : Color(hex: "#E3E3E3"),
                                                lineWidth: 2
                                            )
                                    )
                                }
                                .disabled(isPlaceholderMode)
                            }
                        }
                    }
                }
                .frame(width: 60, height: 196)
            } else {
                // When there is no real product image, use a generic add-image icon
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
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        // Show green tile + three placeholders for adding images
                        Button {
                            isCameraPresentedFromDetail = true
                        } label: {
                            HStack {
                                Image("addimageiconingreen")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                            }
                            .frame(width: 50, height: 50)
                            .background(Color(hex: "#F6FCED"))
                            .cornerRadius(8)
                        }
                        .disabled(isPlaceholderMode)
                        
                        ForEach(0..<3, id: \.self) { _ in
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
                    }
                }
                .frame(width: 60, height: 196)
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
                        Circle()
                            .fill(resolvedStatus.color)
                            .frame(width: 10, height: 10)
                        
                        Text(resolvedStatus.title)
                            .font(NunitoFont.bold.size(14))
                            .foregroundStyle(resolvedStatus.color)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(resolvedStatus.badgeBackground, in: Capsule())
                    
                    HStack(spacing: 12) {
                        Button {
                            thumbSelection = .up
                        } label: {
                            let isSelected = thumbSelection == .up
                            let color = isSelected ? Color(hex: "#FBCB7F") : Color.grayScale100
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(color, lineWidth: 0.5)
                                Image("thumbsup")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 18)
                                    .foregroundStyle(color)
                            }
                            .frame(width: 32, height: 28)
                        }
                        .buttonStyle(.plain)

                        Button {
                            thumbSelection = .down
                        } label: {
                            let isSelected = thumbSelection == .down
                            let color = isSelected ? Color(hex: "#FF594E") : Color.grayScale100
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(color, lineWidth: 0.5)
                                Image("thumbsdown")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 18)
                                    .foregroundStyle(color)
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
                    ForEach(dietaryTags, id: \.name) { tag in
                        DietaryTagView(tag: tag)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
    }
}

#if DEBUG
#Preview("Normal Mode") {
    ProductDetailView(isPlaceholderMode: false)
        .environment(AppNavigationCoordinator())
}

#Preview("Recent Scan Empty State") {
    ProductDetailView(isPlaceholderMode: true)
        .environment(AppNavigationCoordinator())
}

#Preview("Placeholder Mode") {
    ProductDetailView(isPlaceholderMode: true)
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

enum ThumbSelection {
    case up
    case down
}
