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
                // Record that we're showing the prompt
                userPreferences.recordRatingPrompt()
                
                // Use the proper StoreKit API for requesting reviews
                let foregroundScene = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first { $0.activationState == .foregroundActive }
                if let windowScene = foregroundScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
                
                // Set up dismissal detection after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    // If the app becomes active again within 3 seconds, user likely cancelled
                    // We'll record dismissal when the view disappears or app becomes active
                    self.setupDismissalDetection()
                }
            }
        }
    }
    
    private func setupDismissalDetection() {
        // Monitor when the user returns to the app to detect cancellation
        var observerToken: NSObjectProtocol?
        observerToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // User returned to app, likely dismissed the rating prompt
            userPreferences.recordPromptDismissal()
            if let token = observerToken {
                NotificationCenter.default.removeObserver(token)
                observerToken = nil
            }
        }
    }
}
