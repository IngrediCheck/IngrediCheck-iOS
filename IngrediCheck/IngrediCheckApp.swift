import SwiftUI
import PostHog

@main
struct IngrediCheckApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State private var webService = WebService()
    @State private var dietaryPreferences = DietaryPreferences()
    @State private var userPreferences: UserPreferences = UserPreferences()
    @State private var appState = AppState()
    @State private var onboardingState = OnboardingState()
    @State private var authController = AuthController()

    var body: some Scene {
        WindowGroup {
            Splash {
                Image("SplashScreen")
                    .resizable()
                    .scaledToFill()
            } content: {
                MainView()
                    .environment(authController)
                    .environment(webService)
                    .environment(userPreferences)
                    .environment(appState)
                    .environment(dietaryPreferences)
                    .environment(onboardingState)
            }
        }
    }
}

struct MainView: View {

    @State private var networkState = NetworkState()

    @Environment(AuthController.self) var authController
    @Environment(OnboardingState.self) var onboardingState

    var body: some View {
        Group {
            if onboardingState.useCasesShown {
                switch authController.signInState {
                case .signedIn:
                    if onboardingState.disclaimerShown {
                        LoggedInRootView()
                            .tint(.paletteAccent)
                    } else {
                        DisclaimerView()
                    }
                case .signedOut:
                    SignInView()
                case .signingIn:
                    ProgressView()
                }
            } else {
                UseCasesView()
            }
        }
        .overlay {
            if !networkState.connected {
                ContentUnavailableView("Network seems Offline", systemImage: "wifi.slash")
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        AnalyticsService.shared.configure()
        return true
    }
}