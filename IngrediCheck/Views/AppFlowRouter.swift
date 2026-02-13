import SwiftUI

struct AppFlowRouter: View {
    @State private var webService: WebService
    @State private var scanHistoryStore: ScanHistoryStore
    @State private var dietaryPreferences = DietaryPreferences()
    @State private var userPreferences: UserPreferences = UserPreferences()
    @State private var appState = AppState()
    @State private var onboardingState = OnboardingState()
    @State private var authController = AuthController()
    @State private var familyStore: FamilyStore
    @State private var coordinator = AppNavigationCoordinator(initialRoute: .heyThere)
    @State private var memojiStore = MemojiStore()
    @State private var networkState = NetworkState()
    @State private var appResetID = UUID()
    @State private var prefetcher: HomescreenPrefetcher

    init() {
        let ws = WebService()
        let shs = ScanHistoryStore(webService: ws)
        let fs = FamilyStore()
        _webService = State(initialValue: ws)
        _scanHistoryStore = State(initialValue: shs)
        _familyStore = State(initialValue: fs)
        _prefetcher = State(initialValue: HomescreenPrefetcher(
            familyStore: fs, scanHistoryStore: shs, webService: ws
        ))
    }

    var body: some View {
        SplashScreen()
            .preferredColorScheme(.light)
            .environment(authController)
            .environment(webService)
            .environment(scanHistoryStore)
            .environment(userPreferences)
            .environment(appState)
            .environment(dietaryPreferences)
            .environment(onboardingState)
            .environment(familyStore)
            .environment(coordinator)
            .environment(memojiStore)
            .environment(networkState)
            .environment(prefetcher)
            .overlay {
                if !networkState.connected {
                    NoInternetView()
                }
            }
            .id(appResetID)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AppDidReset"))) { _ in
                appResetID = UUID()
                let ws = WebService()
                let shs = ScanHistoryStore(webService: ws)
                let fs = FamilyStore()
                webService = ws
                scanHistoryStore = shs
                dietaryPreferences = DietaryPreferences()
                userPreferences = UserPreferences()
                appState = AppState()
                onboardingState = OnboardingState()
                authController = AuthController()
                familyStore = fs
                coordinator = AppNavigationCoordinator(initialRoute: .heyThere)
                memojiStore = MemojiStore()
                networkState = NetworkState()
                prefetcher = HomescreenPrefetcher(
                    familyStore: fs, scanHistoryStore: shs, webService: ws
                )
            }
    }
}

#Preview {
    AppFlowRouter()
}
