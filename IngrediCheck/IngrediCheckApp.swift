import SwiftUI
import PostHog

@main
struct IngrediCheckApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var webService = WebService()

    var body: some Scene {
        WindowGroup {
            AppFlowRouter()
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

    func applicationDidBecomeActive(_: UIApplication) {
        // Wake up backends on app start and foreground
        WebService().pingFlyIO()
        WebService().ping()
    }
}
