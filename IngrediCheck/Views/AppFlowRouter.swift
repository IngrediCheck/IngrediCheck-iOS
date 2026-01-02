import SwiftUI

/// Routes between production and preview flows based on configuration
struct AppFlowRouter: View {
    @State private var webService = WebService()
    @State private var dietaryPreferences = DietaryPreferences()
    @State private var userPreferences: UserPreferences = UserPreferences()
    @State private var appState = AppState()
    @State private var onboardingState = OnboardingState()
    @State private var authController = AuthController()
    @State private var familyStore = FamilyStore()
    @State private var coordinator = AppNavigationCoordinator(initialRoute: .heyThere)
    @State private var memojiStore = MemojiStore()
    @State private var appResetID = UUID()
    
    var body: some View {
        Group {
            if Config.usePreviewFlow {
                PreviewFlowView()
                    .environment(authController)
                    .environment(webService)
                    .environment(userPreferences)
                    .environment(appState)
                    .environment(dietaryPreferences)
                    .environment(onboardingState)
                    .environment(familyStore)
                    .environment(coordinator)
                    .environment(memojiStore)
            } else {
                ProductionFlowView()
                    .environment(authController)
                    .environment(webService)
                    .environment(userPreferences)
                    .environment(appState)
                    .environment(dietaryPreferences)
                    .environment(onboardingState)
                    .environment(familyStore)
                    .environment(coordinator)
                    .environment(memojiStore)
            }
        }
        .id(appResetID)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AppDidReset"))) { _ in
            appResetID = UUID()
            webService = WebService()
            dietaryPreferences = DietaryPreferences()
            userPreferences = UserPreferences()
            appState = AppState()
            onboardingState = OnboardingState()
            authController = AuthController()
            familyStore = FamilyStore()
            coordinator = AppNavigationCoordinator(initialRoute: .heyThere)
            memojiStore = MemojiStore()
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

#Preview {
    AppFlowRouter()
}
