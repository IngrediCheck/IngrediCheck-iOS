//
//  RecentScanCard.swift
//  IngrediCheck
//
//  Reusable card component for Recent Scans - used in both HomeView and Recent Scans Page
//

import SwiftUI

// MARK: - Card Style

enum RecentScanCardStyle {
    case compact    // HomeView - smaller, no background (parent has container)
    case full       // Recent Scans Page - larger, with background & border
}

struct RecentScanCard: View {
    let scan: DTO.Scan
    let style: RecentScanCardStyle
    var onFavoriteToggle: (String, Bool) -> Void
    var onScanUpdated: ((DTO.Scan) -> Void)?

    @Environment(WebService.self) private var webService
    @Environment(FoodNotesStore.self) private var foodNotesStore
    @State private var isFavorited: Bool
    @State private var isTogglingFavorite: Bool = false
    @State private var isReanalyzing: Bool = false
    @State private var reanalysisRotation: Double = 0
    @State private var localScan: DTO.Scan?

    init(
        scan: DTO.Scan,
        style: RecentScanCardStyle = .full,
        onFavoriteToggle: @escaping (String, Bool) -> Void,
        onScanUpdated: ((DTO.Scan) -> Void)? = nil
    ) {
        self.scan = scan
        self.style = style
        self.onFavoriteToggle = onFavoriteToggle
        self.onScanUpdated = onScanUpdated
        _isFavorited = State(initialValue: scan.is_favorited ?? false)
    }

    // MARK: - Style-based dimensions

    private var imageSize: CGSize {
        switch style {
        case .compact:
            return CGSize(width: 65, height: 78)
        case .full:
            return CGSize(width: 82, height: 98)
        }
    }

    private var imageCornerRadius: CGFloat {
        switch style {
        case .compact:
            return 12
        case .full:
            return 12
        }
    }

    private var cardPadding: CGFloat {
        switch style {
        case .compact:
            return 0
        case .full:
            return 12
        }
    }

    private var spacing: CGFloat {
        switch style {
        case .compact:
            return 12
        case .full:
            return 12
        }
    }

    // MARK: - Computed Properties

    private var currentScan: DTO.Scan {
        localScan ?? scan
    }

    private var product: DTO.Product {
        currentScan.toProduct()
    }

    private var matchStatus: DTO.ProductRecommendation {
        let base = currentScan.toProductRecommendation()

        // If user has no food notes at all, always show a neutral "no preferences"
        // state in history, so recent scans never show "Unknown" while preferences
        // are empty. Once the user adds any preference, we show the real base value.
        if hasNoFoodNotes {
            print("[RecentScanCard] 🟦 noPreferences (hasNoFoodNotes=true) for scan_id=\(currentScan.id)")
            return .noPreferences
        }

        return base
    }

    private var isStale: Bool {
        currentScan.analysis_result?.is_stale ?? false
    }

    private var productName: String {
        product.name ?? "Unknown Product"
    }

    private var brandAndDescription: String? {
        let brand = product.brand?.trimmingCharacters(in: .whitespacesAndNewlines)
        // For now, just show the brand. Could add description if available in data model.
        if let brand, !brand.isEmpty {
            return brand
        }
        return nil
    }

    private var imageLocations: [DTO.ImageLocationInfo] {
        product.images
    }

    private var hasNoFoodNotes: Bool {
        guard let summary = foodNotesStore.foodNotesSummary else {
            return true
        }
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "No Food Notes yet."
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: spacing) {
            // Single product image (left)
            productImageView

            // Content (product info + actions + meta)
            VStack(alignment: .leading, spacing: 8) {
                // Product info and action buttons in one HStack
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(productName)
                            .font(ManropeFont.bold.size(style == .compact ? 14 : 16))
                            .foregroundStyle(.teritairy1000)
                            .lineLimit(2)

                        if let subtitle = brandAndDescription {
                            Text(subtitle)
                                .font(ManropeFont.regular.size(12))
                                .foregroundStyle(.grayScale100)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        // Stale indicator / Reanalysis button (only show when stale or reanalyzing)
                        if isStale || isReanalyzing {
                            Button {
                                if !isReanalyzing {
                                    performReanalysis()
                                }
                            } label: {
                                Image("rotate")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(isReanalyzing ? .grayScale50 : Color(hex: "#FF8A00"))
                                    .rotationEffect(.degrees(reanalysisRotation))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(isReanalyzing ? Color.grayScale20 : Color(hex: "#FFF3E0"))
                            )
                            .disabled(isReanalyzing)
                        }

                        // Favorite heart button
                        Button {
                            toggleFavorite()
                        } label: {
                            Image(systemName: isFavorited ? "heart.fill" : "heart")
                                .font(.system(size: style == .compact ? 16 : 18, weight: .semibold))
                                .foregroundStyle(isFavorited ? Color(hex: "#FF4D4D") : .grayScale80)
                        }
                        .buttonStyle(.plain)
                        .disabled(isTogglingFavorite)
                    }
                }

                Spacer(minLength: style == .compact ? 0 : 8)

                // Match status badge and time in one HStack with Spacer
                HStack(alignment: .bottom, spacing: 8) {
                    matchStatusBadge

                    Spacer()

                    timeBadge
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(cardPadding)
        .background(cardBackground)
        .onChange(of: scan.is_favorited) { _, newValue in
            if let newValue = newValue, !isTogglingFavorite {
                isFavorited = newValue
            }
        }
        .onChange(of: scan.analysis_result?.is_stale) { _, _ in
            // Reset local scan when the parent's scan updates
            localScan = nil
        }
    }

    // MARK: - Card Background

    @ViewBuilder
    private var cardBackground: some View {
        switch style {
        case .compact:
            Color.clear
        case .full:
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 24)
//                        .stroke(Color.grayScale30, lineWidth: 1)
//                )
        }
    }

    // MARK: - Product Image View

    @ViewBuilder
    private var productImageView: some View {
        if let firstImage = imageLocations.first {
            RecentScanImageThumbnail(imageLocation: firstImage)
                .frame(width: imageSize.width, height: imageSize.height)
                .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))
        } else {
            // Placeholder when no images
            ZStack {
                RoundedRectangle(cornerRadius: imageCornerRadius)
                    .fill(Color.grayScale30)
                    .frame(width: imageSize.width, height: imageSize.height)
                Image("imagenotfound1")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageSize.width * 0.4, height: imageSize.height * 0.4)
            }
        }
    }

    // MARK: - Time Badge

    @ViewBuilder
    private var timeBadge: some View {
        HStack(spacing: 6) {
            Image("time")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundStyle(.grayScale80)
            Text(currentScan.shortRelativeTime())
                .font(ManropeFont.regular.size(12))
                .foregroundStyle(.grayScale80)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.grayScale30)
        )
    }

    // MARK: - Match Status Badge

    @ViewBuilder
    private var matchStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(matchStatus.badgeDotColor)
                .frame(width: 8, height: 8)
            Text(matchStatus.displayText)
                .font(ManropeFont.semiBold.size(12))
                .foregroundStyle(matchStatus.badgeTextColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(matchStatus.badgeBackgroundColor)
        )
    }

    // MARK: - Actions

    private func toggleFavorite() {
        guard !isTogglingFavorite else { return }
        let previous = isFavorited
        let next = !previous

        isFavorited = next
        isTogglingFavorite = true
        onFavoriteToggle(scan.id, next)

        Task {
            do {
                let updated = try await webService.toggleFavorite(scanId: scan.id)
                await MainActor.run {
                    isFavorited = updated
                    isTogglingFavorite = false
                    onFavoriteToggle(scan.id, updated)
                }
            } catch {
                await MainActor.run {
                    isFavorited = previous
                    isTogglingFavorite = false
                    onFavoriteToggle(scan.id, previous)
                }
            }
        }
    }

    private func performReanalysis() {
        guard !isReanalyzing else { return }

        Task {
            await MainActor.run {
                isReanalyzing = true
                // Start spinning animation
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    reanalysisRotation = 360
                }
            }

            do {
                Log.debug("RecentScanCard", "Triggering re-analysis for scan: \(scan.id)")
                let updatedScan = try await webService.reanalyzeScan(scanId: scan.id)

                await MainActor.run {
                    localScan = updatedScan
                    isReanalyzing = false
                    withAnimation(.easeOut(duration: 0.3)) {
                        reanalysisRotation = 0
                    }
                    onScanUpdated?(updatedScan)
                    Log.debug("RecentScanCard", "Re-analysis complete for scan: \(scan.id)")
                }
            } catch {
                Log.error("RecentScanCard", "Re-analysis failed: \(error)")
                await MainActor.run {
                    isReanalyzing = false
                    withAnimation(.easeOut(duration: 0.3)) {
                        reanalysisRotation = 0
                    }
                }
            }
        }
    }
}

// MARK: - Image Thumbnail Component

private struct RecentScanImageThumbnail: View {
    let imageLocation: DTO.ImageLocationInfo

    @Environment(WebService.self) private var webService
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.grayScale30)
                Image("imagenotfound1")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            }
        }
        .clipped()
        .task(id: imageLocationKey) {
            guard image == nil else { return }
            do {
                let uiImage = try await webService.fetchImage(imageLocation: imageLocation, imageSize: .small)
                await MainActor.run {
                    image = uiImage
                }
            } catch {
                Log.error("RecentScanCard", "Failed to fetch thumbnail: \(error)")
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

// MARK: - ProductRecommendation Badge Colors Extension

extension DTO.ProductRecommendation {
    var badgeDotColor: Color {
        switch self {
        case .match:
            return Color.primary600
        case .notMatch:
            return Color(hex: "#FF1100")
        case .needsReview:
            return Color(hex: "#FCDE00")
        case .unknown:
            return Color(hex: "#9E9E9E")
        case .noPreferences:
            return Color.grayScale80
        }
    }

    var badgeTextColor: Color {
        switch self {
        case .match:
            return Color.primary600
        case .notMatch:
            return Color(hex: "#FF1100")
        case .needsReview:
            return Color(hex: "#FF594E")
        case .unknown:
            return Color(hex: "#757575")
        case .noPreferences:
            return Color.grayScale100
        }
    }

    var badgeBackgroundColor: Color {
        switch self {
        case .match:
            return Color.primary200
        case .notMatch:
            return Color(hex: "#FFE3E2")
        case .needsReview:
            return Color(hex: "#FFF9CE")
        case .unknown:
            return Color(hex: "#F5F5F5")
        case .noPreferences:
            return Color.grayScale30
        }
    }
}

// MARK: - Short Relative Time Extension

extension DTO.Scan {
    /// Returns a shorter relative time format (e.g., "30 min", "2 hr", "Yesterday")
    func shortRelativeTime(now: Date = Date()) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = isoFormatter.date(from: created_at) else {
            return ""
        }

        let interval = now.timeIntervalSince(date)
        let seconds = Int(interval)

        if seconds < 60 {
            return "Now"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes) min"
        }

        let hours = minutes / 60
        if hours < 24 {
            return hours == 1 ? "1 hr" : "\(hours) hr"
        }

        let days = hours / 24
        if days == 1 {
            return "Yesterday"
        }
        if days < 7 {
            return "\(days) days"
        }

        // For older items, show date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        return dateFormatter.string(from: date)
    }
}

// MARK: - Preview Helper

#if DEBUG
private func makeSampleScan(
    id: String = UUID().uuidString,
    name: String = "Sample Product",
    brand: String = "Sample Brand",
    isFavorited: Bool = false,
    overallMatch: String = "matched",
    minutesAgo: Int = 30,
    isStale: Bool = false
) -> DTO.Scan {
    let productInfo = DTO.ScanProductInfo(
        name: name,
        brand: brand,
        ingredients: [
            DTO.Ingredient(name: "Water", vegan: true, vegetarian: true, ingredients: []),
            DTO.Ingredient(name: "Sugar", vegan: true, vegetarian: true, ingredients: [])
        ],
        images: nil
    )

    // Create a date minutesAgo minutes in the past
    let createdAt: String = {
        let date = Date().addingTimeInterval(-Double(minutesAgo * 60))
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }()

    // Create analysis result from JSON for preview
    let analysisJson = """
    {
        "id": "\(UUID().uuidString)",
        "overall_match": "\(overallMatch)",
        "overall_analysis": "Product analysis complete",
        "ingredient_analysis": [],
        "is_stale": \(isStale)
    }
    """.data(using: .utf8)!
    let analysisResult = try? JSONDecoder().decode(DTO.ScanAnalysisResult.self, from: analysisJson)

    return DTO.Scan(
        id: id,
        scan_type: "barcode",
        barcode: "1234567890",
        state: "done",
        product_info: productInfo,
        product_info_source: "openfoodfacts",
        product_info_vote: nil,
        analysis_result: analysisResult,
        images: [],
        latest_guidance: nil,
        created_at: createdAt,
        last_activity_at: createdAt,
        is_favorited: isFavorited,
        analysis_id: nil
    )
}
#endif

//#Preview("Full Style") {
//    ScrollView {
//        VStack(spacing: 12) {
//            RecentScanCard(
//                scan: makeSampleScan(
//                    name: "Organic Oat Milk",
//                    brand: "Oatly",
//                    isFavorited: true,
//                    overallMatch: "matched",
//                    minutesAgo: 15
//                ),
//                style: .full,
//                onFavoriteToggle: { _, _ in }
//            )
//
//            RecentScanCard(
//                scan: makeSampleScan(
//                    name: "Chocolate Chip Cookies - Strawberry flavor",
//                    brand: "Chips Ahoy",
//                    isFavorited: false,
//                    overallMatch: "unmatched",
//                    minutesAgo: 45,
//                    isStale: true
//                ),
//                style: .full,
//                onFavoriteToggle: { _, _ in }
//            )
//
//            RecentScanCard(
//                scan: makeSampleScan(
//                    name: "Protein Bar",
//                    brand: "Quest",
//                    isFavorited: false,
//                    overallMatch: "uncertain",
//                    minutesAgo: 120
//                ),
//                style: .full,
//                onFavoriteToggle: { _, _ in }
//            )
//        }
//        .padding(20)
//    }
//    .background(Color.pageBackground)
//    .environment(WebService())
//}

//#Preview("Compact Style") {
//    ScrollView {
//        VStack(spacing: 0) {
//            ForEach(0..<3, id: \.self) { index in
//                RecentScanCard(
//                    scan: makeSampleScan(
//                        name: index == 0 ? "Organic Oat Milk" : index == 1 ? "Chocolate Chip Cookies" : "Protein Bar",
//                        brand: index == 0 ? "Oatly" : index == 1 ? "Chips Ahoy" : "Quest",
//                        isFavorited: index == 0,
//                        overallMatch: index == 0 ? "matched" : index == 1 ? "unmatched" : "uncertain",
//                        minutesAgo: index == 0 ? 15 : index == 1 ? 45 : 120,
//                        isStale: index == 1
//                    ),
//                    style: .compact,
//                    onFavoriteToggle: { _, _ in }
//                )
//                .padding(.vertical, 12)
//
//                if index < 2 {
//                    Divider()
//                        .background(Color.grayScale30)
//                }
//            }
//        }
//        .padding(.horizontal, 16)
//        .background(
//            RoundedRectangle(cornerRadius: 24)
//                .fill(Color.white)
//        )
//        .padding(20)
//    }
//    .background(Color.pageBackground)
//    .environment(WebService())
//}
