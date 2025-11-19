//
//  ProductDetailView.swift
//  IngrediCheckPreview
//
//  Created on 18/11/25.
//

import SwiftUI

struct ProductDetailView: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @State private var isFavorite = false
    @State private var isDescriptionExpanded = false
    @State private var isIngredientsExpanded = false
    @State private var isIngredientsAlertExpanded = false
    @State private var selectedImageIndex = 0
    @State private var activeIngredientHighlight: IngredientHighlight?
    
    var isPlaceholderMode: Bool = false
    
    private let productImages = ["corn-flakes", "corn-flakes", "corn-flakes", "corn-flakes"]
    private let productBrand = "Nestlé"
    private let productName = "Maggi 2-Minute Noodles"
    private let productDetails = "Instant Noodles · Pack of 70g"
    private let productStatus = "Unmatched"
    private let productStatusColor = Color(hex: "#FF1100")
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
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                productGallery
                productInformation
                dietaryTagsRow
                
                
                IngredientsAlertCard(
                    isExpanded: $isIngredientsAlertExpanded,
                    items: ingredientAlertItems
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
                        activeHighlight: $activeIngredientHighlight
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
    }
    
    private var header: some View {
        HStack {
            Button {
                coordinator.showCanvas(.home)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.grayScale150)
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
            Image(productImages[selectedImageIndex])
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaledToFill()
                .frame(
                    width: UIScreen.main.bounds.width * 0.704,
                    height: UIScreen.main.bounds.height * 0.234
                )
                .cornerRadius(16)
                .clipped()
            
            VStack(spacing: 8) {
                ForEach(0..<min(3, productImages.count), id: \.self) { index in
                    Button {
                        if !isPlaceholderMode {
                            selectedImageIndex = index
                        }
                    } label: {
                        if isPlaceholderMode {
                            Image("imagePh")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundStyle(.grayScale60)
                                .background(Color.grayScale40)
                                .cornerRadius(8)
                        } else {
                            Image(productImages[index])
                                .resizable()
                                .scaledToFill()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                .clipped()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            selectedImageIndex == index ? Color.primary600 : .clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                    }
                    .disabled(isPlaceholderMode)
                }
            }
        }
        .padding(.bottom, 20)
    }
    
    private var productInformation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(productBrand)
                .font(ManropeFont.regular.size(14))
                .foregroundStyle(.grayScale100)
            
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(productName)
                        .font(NunitoFont.bold.size(20))
                        .foregroundStyle(.grayScale150)
                    
                    Text(productDetails)
                        .font(ManropeFont.medium.size(14))
                        .foregroundStyle(.grayScale100)
                }
                
                VStack(alignment: .trailing, spacing: 16) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(productStatusColor)
                            .frame(width: 10, height: 10)
                        
                        Text(productStatus)
                            .font(NunitoFont.bold.size(14))
                            .foregroundStyle(productStatusColor)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(productStatusColor.opacity(0.1), in: Capsule())
                    
                    HStack(spacing: 12) {
                        Image("thumbsup")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 28)
                            .foregroundStyle(.grayScale100)
                        
                        Image("thumbsdown")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 28)
                            .foregroundStyle(.grayScale100)
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

#Preview("Normal Mode") {
    ProductDetailView(isPlaceholderMode: false)
        .environment(AppNavigationCoordinator())
}

#Preview("Placeholder Mode") {
    ProductDetailView(isPlaceholderMode: true)
        .environment(AppNavigationCoordinator())
}

