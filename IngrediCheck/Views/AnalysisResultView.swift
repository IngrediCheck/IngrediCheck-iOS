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
                CapsuleWithDivider(state: .success)
            case .needsReview:
                CapsuleWithDivider(state: .warning)
            case .notMatch:
                CapsuleWithDivider(state: .fail)
            }
        } else {
            CapsuleWithDivider(state: .analyzing)
        }
    }
}
