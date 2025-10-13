//
//  AnalysisResultView.swift
//  IngrediCheck
//
//  Created by sanket patel on 2/8/24.
//

import SwiftUI
import StoreKit

struct AnalysisResultView: View {

    let product: DTO.Product
    let ingredientRecommendations: [DTO.IngredientRecommendation]?
    
    @Environment(UserPreferences.self) var userPreferences
    @Environment(\.requestReview) var requestReview

    var body: some View {
        if let ingredientRecommendations {
            switch product.calculateMatch(ingredientRecommendations: ingredientRecommendations) {
            case .match:
                CapsuleWithDivider(state: .success)
                    .onAppear {
                        checkAndPromptForRating()
                    }
            case .needsReview:
                CapsuleWithDivider(state: .warning)
                    .onAppear {
                        checkAndPromptForRating()
                    }
            case .notMatch:
                CapsuleWithDivider(state: .fail)
                    .onAppear {
                        checkAndPromptForRating()
                    }
            }
        } else {
            CapsuleWithDivider(state: .analyzing)
        }
    }
    
    private func checkAndPromptForRating() {
        // Check if we should prompt for rating
        if userPreferences.canPromptForRating() {
            // Small delay to ensure the UI is settled before showing the prompt
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                requestReview()
                userPreferences.recordRatingPrompt()
            }
        }
    }
}
