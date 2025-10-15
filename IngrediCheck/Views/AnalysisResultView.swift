//
//  AnalysisResultView.swift
//  IngrediCheck
//
//  Created by sanket patel on 2/8/24.
//

import SwiftUI
import StoreKit

/// Helper class to manage notification observer lifecycle
class RatingPromptDismissalObserver {
    private var observer: NSObjectProtocol?
    private let userPreferences: UserPreferences
    
    init(userPreferences: UserPreferences) {
        self.userPreferences = userPreferences
    }
    
    func setupObserver() {
        // Remove any existing observer first
        removeObserver()
        
        // Monitor when the user returns to the app to detect cancellation
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // User returned to app, likely dismissed the rating prompt
            self?.userPreferences.recordPromptDismissal()
            self?.removeObserver()
        }
    }
    
    func removeObserver() {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
    
    deinit {
        removeObserver()
    }
}

struct AnalysisResultView: View {

    let product: DTO.Product
    let ingredientRecommendations: [DTO.IngredientRecommendation]?
    
    @Environment(UserPreferences.self) var userPreferences
    @State private var dismissalObserver: RatingPromptDismissalObserver?

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
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                } else {
                    SKStoreReviewController.requestReview()
                }
                
                // Set up dismissal detection after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    // Create and setup the observer to detect cancellation
                    let observer = RatingPromptDismissalObserver(userPreferences: userPreferences)
                    dismissalObserver = observer
                    observer.setupObserver()
                }
            }
        }
    }
}
