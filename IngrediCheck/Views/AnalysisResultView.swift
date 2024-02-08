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
                    Text("Match!")
                }
            case .needsReview:
                CapsuleWithDivider(color: .orange) {
                    Text("Needs Review")
                }
            case .notMatch:
                CapsuleWithDivider(color: .red) {
                    Text("Does not Match :(")
                }
            }
        } else {
            CapsuleWithDivider(color: .blue) {
                HStack(spacing: 25) {
                    ProgressView()
                    Text("Analyzing...")
                }
            }
        }
    }
}
