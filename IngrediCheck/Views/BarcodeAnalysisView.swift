import SwiftUI

struct HeaderImage: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFit()
        } placeholder: {
            ProgressView()
        }
        .clipped()
    }
}

struct DownvoteButton: View {
    @Binding var rating: Int
    let clientActivityId: String
    @Environment(WebService.self) var webService
    
    func buttonImage(systemName: String, foregroundColor: Color) -> some View {
        Image(systemName: systemName)
            .frame(width: 20, height: 20)
            .font(.title3.weight(.thin))
            .foregroundColor(foregroundColor)
    }
    
    var body: some View {
        Button(action: {
            withAnimation {
                self.rating = (self.rating == -1) ? 0 : -1
            }
            Task {
                try? await webService.rateAnalysis(clientActivityId: clientActivityId, rating: self.rating)
            }
        }, label: {
            buttonImage(
                systemName: rating == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                foregroundColor: .paletteAccent
            )
        })
    }
}

struct UpvoteButton: View {
    @Binding var rating: Int
    let clientActivityId: String
    @Environment(WebService.self) var webService

    func buttonImage(systemName: String, foregroundColor: Color) -> some View {
        Image(systemName: systemName)
            .frame(width: 20, height: 20)
            .font(.title3.weight(.thin))
            .foregroundColor(foregroundColor)
    }

    var body: some View {
        Button(action: {
            withAnimation {
                self.rating = (self.rating == 1) ? 0 : 1
            }
            Task {
                try? await webService.rateAnalysis(clientActivityId: clientActivityId, rating: self.rating)
            }
        }, label: {
            buttonImage(
                systemName: rating == 1 ? "hand.thumbsup.fill" : "hand.thumbsup",
                foregroundColor: .paletteAccent
            )
        })
    }
}

struct BarcodeAnalysisView: View {
    
    let barcode: String
    let clientActivityId = UUID().uuidString
    
    @Environment(WebService.self) var webService
    @Environment(UserPreferences.self) var userPreferences
    
    @State private var rating: Int = 0
    @State private var product: DTO.Product? = nil
    @State private var error: Error? = nil
    @State private var ingredientRecommendations: [DTO.IngredientRecommendation]? = nil

    var body: some View {
        if let error = self.error {
            Text("Error: \(error.localizedDescription)")
        } else if let product = self.product {
            ScrollView {
                VStack(spacing: 25) {
                    if case let .url(url) = product.images.first {
                        HeaderImage(url: url)
                    }
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
                            userPreferenceText: userPreferences.asString,
                            barcode: barcode
                        )
                } catch {
                    self.error = error
                }
            }
        } else {
            VStack {
                Spacer()
                Text("Looking up \(barcode)")
                Spacer()
                ProgressView()
                Spacer()
            }
            .task {
                do {
                    self.product = try await webService.fetchProductDetailsFromBarcode(barcode: barcode)
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
