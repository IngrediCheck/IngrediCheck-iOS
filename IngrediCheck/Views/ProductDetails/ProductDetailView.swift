//
//  ProductDetailView.swift
//  IngrediCheckPreview
//
//  Created on 18/11/25.
//

import SwiftUI

struct ProductDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isFavorite = false
    @State private var isDescriptionExpanded = false
    @State private var isIngredientsExpanded = false
    @State private var isIngredientsAlertExpanded = false
    @State private var selectedImageIndex = 0
    @State private var activeIngredientHighlight: IngredientHighlight?
    @State private var thumbSelection: ThumbSelection? = nil
    @State private var isCameraPresentedFromDetail = false
    
    var product: DTO.Product? = nil
    var matchStatus: DTO.ProductRecommendation? = nil
    var ingredientRecommendations: [DTO.IngredientRecommendation]? = nil
    var isPlaceholderMode: Bool = false
    
    private let fallbackProductImages = ["maggie1", "maggie2"]
    private let fallbackProductBrand = "Nestlé"
    private let fallbackProductName = "Maggi 2-Minute Noodles"
    private let fallbackProductDetails = "Instant Noodles · Pack of 70g"
    private let fallbackProductStatus: ProductMatchStatus = .matched
    private let dietaryTags = [
        DietaryTag(name: "Dairy-free", icon: "dairy"),
        DietaryTag(name: "Vegetarian", icon: "vegetarian"),
        DietaryTag(name: "High Sodium", icon: "salt")
    ]
    private let descriptionText = "Maggi 2-Minute Noodles is a popular instant noodle product known for its quick preparation time and distinctive masala flavor. Made with refined flour and palm oil, it's a convenient meal option."
    
    private let ingredientAlertItems: [IngredientAlertItem] = [
        .init(
            name: "Wheat Flour (Maida)",
            detail: "Refined grain, lacks fiber and nutrients. Those avoiding refined carbs or gluten-sensitive individuals.",
            status: .unmatched
        ),
        .init(
            name: "Edible Vegetable Oil (Palm Oil)",
            detail: "Processed oil, not heart-healthy or low-waste. Not suitable for heart health–focused or sustainability-conscious users.",
            status: .unmatched
        ),
        .init(
            name: "Garlic, Onion",
            detail: "Restricted for users following Jain / Satvik / no-onion-garlic diets.",
            status: .unmatched
        ),
        .init(
            name: "Flavor Enhancers (INS 627, INS 631)",
            detail: "Disodium guanylate and disodium inosinate (MSG family). Not suitable for those avoiding MSG or artificial additives.",
            status: .unmatched
        ),
        .init(
            name: "Hydrolyzed Groundnut Protein",
            detail: "Allergen risk (peanut derivative). Not suitable for peanut allergy, gut-sensitive, or additive-averse users.",
            status: .uncertain
        ),
        .init(
            name: "Salt (High Sodium)",
            detail: "High sodium intake risk. Not suitable for users managing hypertension, kidney health, or balanced sodium diets.",
            status: .uncertain
        )
    ]
    
    private let ingredientParagraphs: [IngredientParagraph] = [
        .init(
            title: "Noodles :",
            body: "Refined wheat flour (maida), edible vegetable oil (palm oil), salt, wheat gluten, mineral (calcium carbonate), thickener (INS 412), acidity regulator (INS 501), humectant (INS 451), color (INS 150d).",
            highlights: [
                .init(phrase: "Refined wheat flour (maida)", reason: "Highly processed flour with low fiber; can trigger glucose spikes."),
                .init(phrase: "edible vegetable oil (palm oil)", reason: "Palm oil is high in saturated fats; not ideal for heart health or sustainability."),
                .init(phrase: "acidity regulator (INS 501)", reason: "Processed additive; may not align with whole-food preferences."),
                .init(phrase: "humectant (INS 451)", reason: "Synthetic moisture-retaining additive flagged for clean-label diets."),
                .init(phrase: "color (INS 150d)", reason: "Artificial caramel coloring that some users try to avoid.")
            ]
        ),
        .init(
            title: "Tastemaker (Masala):",
            body: "Mixed spices (coriander, turmeric, chili, garlic, onion, ginger, black pepper), salt, sugar, flavor enhancer (INS 627, INS 631), hydrolyzed groundnut protein, wheat flour, maltodextrin, edible starch, and dehydrated vegetables (garlic, onion).",
            highlights: [
                .init(phrase: "flavor enhancer (INS 627, INS 631)", reason: "MSG-family enhancers that can cause sensitivities for some users."),
                .init(phrase: "hydrolyzed groundnut protein", reason: "Contains peanut derivatives; flagged for allergy and gut concerns."),
                .init(phrase: "edible starch", reason: "Highly processed thickener with little nutritional value.")
            ]
        )
    ]
    
    private var resolvedBrand: String {
        if let brand = product?.brand, !brand.isEmpty {
            return brand
        }
        return fallbackProductBrand
    }
    
    private var resolvedName: String {
        if let name = product?.name, !name.isEmpty {
            return name
        }
        return fallbackProductName
    }
    
    private var resolvedDetails: String {
        fallbackProductDetails
    }
    
    private var resolvedStatus: ProductMatchStatus {
        guard let matchStatus else {
            return fallbackProductStatus
        }
        switch matchStatus {
        case .match:
            return .matched
        case .needsReview:
            return .uncertain
        case .notMatch:
            return .unmatched
        }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                productGallery
                productInformation
                dietaryTagsRow
                
                
                IngredientsAlertCard(
                    isExpanded: $isIngredientsAlertExpanded,
                    items: ingredientAlertItems,
                    status: resolvedStatus
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                CollapsibleSection(
                    title: "Description",
                    isExpanded: $isDescriptionExpanded
                ) {
                    Text(descriptionText)
                        .font(ManropeFont.regular.size(14))
                        .foregroundStyle(.grayScale110)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                CollapsibleSection(
                    title: "Ingredients",
                    isExpanded: $isIngredientsExpanded
                ) {
                    IngredientDetailsView(
                        paragraphs: ingredientParagraphs,
                        activeHighlight: $activeIngredientHighlight,
                        highlightColor: resolvedStatus.color
                    )
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
            if let product, !product.images.isEmpty {
                HeaderImage(imageLocation: product.images[selectedImageIndex])
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

                        if product.images.count <= 2 {
                            // Up to three slots: real images first (if any), then placeholder(s)
                            ForEach(0..<3, id: \.self) { index in
                                if index < product.images.count {
                                    Button {
                                        if !isPlaceholderMode {
                                            selectedImageIndex = index
                                        }
                                    } label: {
                                        HeaderImage(imageLocation: product.images[index])
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
                            ForEach(product.images.indices, id: \.self) { index in
                                Button {
                                    if !isPlaceholderMode {
                                        selectedImageIndex = index
                                    }
                                } label: {
                                    HeaderImage(imageLocation: product.images[index])
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
                // for the large image area in normal mode, but keep the Maggi
                // placeholders for design/preview (placeholder mode).
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color(hex: "#CECECE").opacity(0.25), radius: 12)
                    if isPlaceholderMode {
                        Image(fallbackProductImages[selectedImageIndex])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(16)
                            .clipped()
                    } else {
                        Image("addimageiconlarge")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 85, height: 79)
                    }
                }
                .frame(
                    width: UIScreen.main.bounds.width * 0.704,
                    height: UIScreen.main.bounds.height * 0.234
                )
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        if isPlaceholderMode {
                            // Placeholder mode: show the add-photo tile followed by
                            // the static Maggi thumbnails, like the original design.
                            Button {
                                // Add photo action
                            } label: {
                                Image("addimageiconsmall")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .foregroundStyle(.grayScale60)
                                    .background(Color.grayScale40)
                                    .cornerRadius(8)
                            }
                            .disabled(isPlaceholderMode)
                            
                            ForEach(0..<fallbackProductImages.count, id: \.self) { index in
                                Button {
                                    if !isPlaceholderMode {
                                        selectedImageIndex = index
                                    }
                                } label: {
                                    Image(fallbackProductImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .aspectRatio(contentMode: .fill)
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
                        } else {
                            // Real-data mode with no images: show green tile + three placeholders
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
              
                        Text(resolvedDetails)
                            .font(ManropeFont.medium.size(14))
                            .foregroundStyle(.grayScale100)
                    
                }
                
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
    
    private var dietaryTagsRow: some View {
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
    
    var title: String {
        switch self {
        case .matched: return "Matched"
        case .uncertain: return "Uncertain"
        case .unmatched: return "Unmatched"
        }
    }
    
    var color: Color {
        switch self {
        case .matched: return Color(hex: "#5A9C19")
        case .uncertain: return Color(hex: "#E9A600")
        case .unmatched: return Color(hex: "#FF4E50")
        }
    }
    
    var badgeBackground: Color {
        switch self {
        case .matched: return Color(hex: "#EAF6D9")
        case .uncertain: return Color(hex: "#FFF5DA")
        case .unmatched: return Color(hex: "#FFE3E2")
        }
    }
    
    var alertTitle: String {
        switch self {
        case .matched: return "Great Match"
        case .uncertain: return "Partially Compatible"
        case .unmatched: return "Ingredients Alerts"
        }
    }
    
    var alertCardBackground: Color {
        switch self {
        case .matched: return Color(hex: "#F3FAE7")
        case .uncertain: return Color(hex: "#FFF8E8")
        case .unmatched: return Color(hex: "#FFEAEA")
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
