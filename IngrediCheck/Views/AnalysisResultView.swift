//
//  AnalysisResultView.swift
//  IngrediCheck
//
//  Created by sanket patel on 2/8/24.
//

import SwiftUI

struct AnalysisResultView: View {

    let product: DTO.Product
    let ingredientRecommendations: [DTO.IngredientRecommendation]?

    var body: some View {
        if let ingredientRecommendations {
            switch product.calculateMatch(ingredientRecommendations: ingredientRecommendations) {
            case .match:
                CapsuleWithDivider(color: .green) {
                    HStack(spacing: 15) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Matched")
                    }
                }
            case .needsReview:
                CapsuleWithDivider(color: .yellow) {
                    HStack(spacing: 15) {
                        Image(systemName: "questionmark.circle.fill")
                        Text("Uncertain")
                    }
                }
            case .notMatch:
                CapsuleWithDivider(color: .red) {
                    HStack(spacing: 15) {
                        Image(systemName: "x.circle.fill")
                        Text("Unmatched")
                    }
                }
            }
        } else {
            CapsuleWithDivider(color: .paletteAccent) {
                HStack(spacing: 25) {
                    ProgressView()
                    Text("Analyzing")
                }
            }
        }
    }
}
