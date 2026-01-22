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

        // Configure navigation bar appearance globally
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0xFC/255.0, green: 0xFC/255.0, blue: 0xFC/255.0, alpha: 1.0) // #FCFCFC
        appearance.shadowColor = .clear // Remove bottom border/shadow
        appearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear] // Hide "Back" text

        // Create custom back indicator with 20px leading padding
        let backImage = UIImage(systemName: "chevron.left")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
            .withTintColor(UIColor(red: 0x30/255.0, green: 0x30/255.0, blue: 0x30/255.0, alpha: 1.0), renderingMode: .alwaysOriginal)
            .withAlignmentRectInsets(UIEdgeInsets(top: 0, left: -12, bottom: 0, right: 0)) // Add left padding

        appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        // Set back button color to #303030 (fallback for other elements)
        UINavigationBar.appearance().tintColor = UIColor(red: 0x30/255.0, green: 0x30/255.0, blue: 0x30/255.0, alpha: 1.0)

        return true
    }

    func applicationDidBecomeActive(_: UIApplication) {
        // Wake up backends on app start and foreground
        WebService().pingFlyIO()
        WebService().ping()
    }
}
