import SwiftUI

/// Routes between production and preview flows based on configuration
struct AppFlowRouter: View {
    @State private var webService = WebService()
    @State private var dietaryPreferences = DietaryPreferences()
    @State private var userPreferences: UserPreferences = UserPreferences()
    @State private var appState = AppState()
    @State private var onboardingState = OnboardingState()
    @State private var authController = AuthController()
    
    var body: some View {
        if Config.usePreviewFlow {
            PreviewFlowView()
        } else {
            ProductionFlowView()
                .environment(authController)
                .environment(webService)
                .environment(userPreferences)
                .environment(appState)
                .environment(dietaryPreferences)
                .environment(onboardingState)
        }
    }
}

// MARK: - Production Flow
private struct ProductionFlowView: View {
    var body: some View {
        Splash {
            Image("SplashScreen")
                .resizable()
                .scaledToFill()
        } content: {
            MainView()
        }
    }
}

// MARK: - Preview/Testing Flow
private struct PreviewFlowView: View {
    var body: some View {
        SplashScreen()
            .preferredColorScheme(.light)
    }
}
