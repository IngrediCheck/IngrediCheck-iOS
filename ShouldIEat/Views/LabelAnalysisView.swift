
import SwiftUI

struct LabelAnalysisView: View {
    let ingredientLabel: IngredientLabel
    let userPreferenceText: String
    let clientActivityId = UUID().uuidString
    @Environment(WebService.self) var webService

    @State private var rating: Int = 0
    @State private var product: DTO.Product? = nil
    @State private var error: Error? = nil
    @State private var ingredientRecommendations: [DTO.IngredientRecommendation]? = nil
    
    var body: some View {
        if let error = self.error {
            Text("Error: \(error.localizedDescription)")
        } else if let product = self.product {
            ScrollView {
                VStack(spacing: 20) {
                    Image(uiImage: ingredientLabel.image)
                        .resizable()
                        .scaledToFit()
                    if let brand = product.brand {
                        Text(brand)
                    }
                    if let name = product.name {
                        Text(name)
                    }
                    
                   Text(product.decoratedIngredientsList(ingredientRecommendations: ingredientRecommendations))
                    
                    if let _ = self.ingredientRecommendations {
                        HStack(spacing: 25) {
                            Spacer()
                            UpvoteButton(rating: $rating, clientActivityId: clientActivityId)
                            DownvoteButton(rating: $rating, clientActivityId: clientActivityId)
                        }
                    } else {
                        HStack(spacing: 25) {
                            Text("Analyzing your preferences...")
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .padding()
            }
            .task {
                do {
                    self.ingredientRecommendations =
                        try await webService.fetchIngredientRecommendations(
                            clientActivityId: clientActivityId,
                            userPreferenceText: userPreferenceText
                        )
                } catch {
                    self.error = error
                }
            }
        } else {
            VStack {
                Spacer()
                Text("Analyzing Image...")
                Spacer()
                ProgressView()
                Spacer()
            }
            .task {
                do {
                    self.product = try await webService.extractProductDetailsFromLabelImages(
                        clientActivityId: clientActivityId,
                        labelImages: [ingredientLabel]
                    )
                } catch {
                    self.error = error
                }
            }
        }
    }
    
    private func rowBackground(forItem ingredient: DTO.Ingredient) -> Color {
        if let ingredientRecommendations = self.ingredientRecommendations {
            let matchingRecommendation =
                ingredientRecommendations.filter { ingredientRecommendation in
                    ingredientRecommendation.ingredientName.lowercased() == ingredient.name.lowercased()
                }

            if !matchingRecommendation.isEmpty {
                switch matchingRecommendation.first!.safetyRecommendation {
                case .definitelyUnsafe:
                    return .red.opacity(0.50)
                case .maybeUnsafe:
                    return .yellow.opacity(0.50)
                }
            }
        }
        return .clear
    }
}
