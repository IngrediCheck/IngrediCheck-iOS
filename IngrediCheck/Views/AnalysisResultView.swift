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
    @Environment(\.scenePhase) private var scenePhase
    @State private var awaitingRatingOutcome = false
    @State private var ratingPromptPresentedAt: Date?
    @State private var dismissalFallbackTask: Task<Void, Never>?

    var body: some View {
        Group {
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
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onDisappear {
            dismissalFallbackTask?.cancel()
            dismissalFallbackTask = nil
            awaitingRatingOutcome = false
            ratingPromptPresentedAt = nil
        }
    }
    
    private func checkAndPromptForRating() {
        // Check if we should prompt for rating
        if userPreferences.canPromptForRating() {
            // Small delay to ensure the UI is settled before showing the prompt
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Record that we're showing the prompt
                userPreferences.recordRatingPrompt()
                ratingPromptPresentedAt = Date()
                awaitingRatingOutcome = true
                scheduleDismissalFallback()

                // Use the proper StoreKit API for requesting reviews
                let foregroundScene = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first { $0.activationState == .foregroundActive }
                if let windowScene = foregroundScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
            }
        }
    }

    private func scheduleDismissalFallback() {
        dismissalFallbackTask?.cancel()
        dismissalFallbackTask = Task {
            try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
            await MainActor.run {
                guard awaitingRatingOutcome else { return }
                guard scenePhase == .active else { return }
                handleRatingPromptFinished(recordDismissal: true)
            }
        }
    }

    private func handleRatingPromptFinished(recordDismissal: Bool) {
        dismissalFallbackTask?.cancel()
        dismissalFallbackTask = nil
        defer {
            awaitingRatingOutcome = false
            ratingPromptPresentedAt = nil
        }
        if recordDismissal {
            userPreferences.recordPromptDismissal()
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard awaitingRatingOutcome else { return }
        switch newPhase {
        case .active:
            if let start = ratingPromptPresentedAt {
                let elapsed = Date().timeIntervalSince(start)
                // Treat quick returns as cancellations so we unlock the 7-day retry.
                if elapsed < 5.0 {
                    handleRatingPromptFinished(recordDismissal: true)
                } else {
                    handleRatingPromptFinished(recordDismissal: false)
                }
            } else {
                handleRatingPromptFinished(recordDismissal: true)
            }
        case .background:
            handleRatingPromptFinished(recordDismissal: false)
        default:
            break
        }
    }
}
