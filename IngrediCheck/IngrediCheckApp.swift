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
        
        configurePostHog()
        
        return true
    }
    
    
    private func configurePostHog() {
        let POSTHOG_API_KEY = "phc_BFYelq2GeyigXBP3MgML57wKoWfLe5MW7m6HMYhtX8m"
        let POSTHOG_HOST = "https://us.i.posthog.com"

        let config = PostHogConfig(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        
        
        // some required permission for config - Ref KIN Cal App
        config.captureApplicationLifecycleEvents = true
        
        config.sessionReplay = true
        
        config.sessionReplayConfig.maskAllTextInputs = false
        
        config.sessionReplayConfig.maskAllImages = false
        
        config.sessionReplayConfig.maskAllSandboxedViews = true
        
        config.sessionReplayConfig.captureNetworkTelemetry = true
        
        config.sessionReplayConfig.screenshotMode = true
        
        config.sessionReplayConfig.throttleDelay = 1.0
        
        PostHogSDK.shared.setup(config)
    }
}



