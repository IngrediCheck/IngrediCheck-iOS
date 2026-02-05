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

class AppDelegate: NSObject, UIApplicationDelegate {
    /// Stores shortcut item from cold launch until the UI is ready to handle it
    static var pendingShortcutItem: UIApplicationShortcutItem?

    /// Published flag to trigger feedback shortcut handling
    @Published var shouldShowFeedbackShortcut = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        AnalyticsService.shared.configure()

        // Configure navigation bar appearance globally
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0xF2/255.0, green: 0xF2/255.0, blue: 0xF9/255.0, alpha: 1.0) // #F2F2F9 (pageBackground)
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

    // Configure scene delegate for handling shortcuts
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Check for shortcut from cold launch via scene connection
        if let shortcutItem = options.shortcutItem {
            AppDelegate.pendingShortcutItem = shortcutItem
        }

        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = ShortcutSceneDelegate.self
        return config
    }
}

/// Scene delegate to handle quick action shortcuts
class ShortcutSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        // Warm launch: app is in background, post notification
        if shortcutItem.type == "SendFeedback" {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("ShowFeedbackFromShortcut"),
                    object: nil
                )
            }
        }
        completionHandler(true)
    }
}
