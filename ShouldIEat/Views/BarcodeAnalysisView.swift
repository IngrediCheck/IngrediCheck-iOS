//
//  BarcodeAnalysisView.swift
//  ShouldIEat
//
//  Created by sanket patel on 2/1/24.
//

import SwiftUI

import SwiftUI

struct HeaderImage: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable()
                 .aspectRatio(contentMode: .fit)
        } placeholder: {
            ProgressView()
        }
        .clipped()
    }
}

struct BarcodeAnalysisView: View {
    let barcode: String
    let userPreferenceText: String
    let clientActivityId = UUID().uuidString
    @Environment(WebService.self) var webService
    
    @State private var product: DTO.Product? = nil
    @State private var error: Error? = nil
    @State private var ingredientRecommendations: [DTO.IngredientRecommendation] = []
    @State private var rating: Int = 0
    
    func buttonImage(systemName: String, foregroundColor: Color) -> some View {
        Image(systemName: systemName)
            .frame(width: 20, height: 20)
            .font(.title3.weight(.thin))
            .foregroundColor(foregroundColor)
    }
    
    var upVoteButton : some View {
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
    
    var downVoteButton : some View {
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

    var body: some View {
        if let error = self.error {
            Text("Error: \(error.localizedDescription)")
        } else if let product = self.product {
            List {
                Section(header: Text("Header").hidden()) {
                    VStack {
                        if let url = product.images.first?.url {
                            HeaderImage(url: url)
                        }
                        if let brand = product.brand {
                            Text(brand)
                        }
                        Text(product.name)
                    }
                }
                Section(header: Text("Feedback").hidden()) {
                    HStack(spacing: 25) {
                        Text("Not accurate?")
                        Spacer()
                        downVoteButton
//                        upVoteButton
                    }
                }
                ForEach(product.ingredients, id: \.self) { ingredient in
                    Text(ingredient.name.capitalized)
                        .listRowBackground(self.rowBackground(forItem: ingredient))
                }
            }
            .task {
                do {
                    self.ingredientRecommendations =
                        try await webService.fetchIngredientRecommendations(
                            clientActivityId: clientActivityId,
                            barcode: barcode,
                            userPreferenceText: userPreferenceText
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
                    self.product = try await webService.fetchProduct(barcode: barcode)
                } catch {
                    self.error = error
                }
            }
        }
    }
    
    private func rowBackground(forItem ingredient: DTO.Ingredient) -> Color {
        let recommendations =
            self.ingredientRecommendations.filter { ingredientRecommendation in
                ingredientRecommendation.ingredientName.lowercased() == ingredient.name.lowercased()
            }
        
        if !recommendations.isEmpty {
            switch recommendations[0].safetyRecommendation {
            case .definitelyUnsafe:
                return .red
            case .maybeUnsafe:
                return .yellow
            }
        }
        
        /*
        if let vegetarian = ingredient.vegetarian, !vegetarian {
            return .red
        }
        if let vegan = ingredient.vegan, !vegan {
            return .yellow
        }
        if let vegetarian = ingredient.vegetarian,
           let vegan = ingredient.vegan,
           vegetarian && vegan {
            return .green
        }
         */
        return .clear
    }
}
