import SwiftUI
import PostHog

@main
struct IngrediCheckApp: App {
    
    @Environment(\.scenePhase) var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State private var webService = WebService()
    @State private var dietaryPreferences = DietaryPreferences()
    @State private var userPreferences: UserPreferences = UserPreferences()
    @State private var appState = AppState()
    @State private var onboardingState = OnboardingState()
    @State private var authController = AuthController()
    @State private var shortcutFeedbackData: FeedbackData?
    @State private var pendingFeedbackAction: Bool = false

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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowFeedbackFromShortcut"))) { _ in
                 handleFeedbackShortcut()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                if let shortcutItem = AppDelegate.pendingShortcutItem {
                    if shortcutItem.type == "com.ingredicheck.feedback" {
                         handleFeedbackShortcut()
                         AppDelegate.pendingShortcutItem = nil
                    }
                }
            }
        }
        .onChange(of: authController.signInState) { oldState, newState in
            if newState == .signedIn && pendingFeedbackAction {
                pendingFeedbackAction = false
                handleFeedbackShortcut()
            }
        }
    }
    
    private func handleFeedbackShortcut() {
        if authController.signInState == .signingIn {
            pendingFeedbackAction = true
            return
        }
        
        // Only show feedback if user is signed in (required for submission)
        guard case .signedIn = authController.signInState else {
            pendingFeedbackAction = false
            return
        }
        
        // Reset deferred flag if we proceed
        pendingFeedbackAction = false
        
        Task { @MainActor in
            @Bindable var appState = appState
            shortcutFeedbackData = FeedbackData()
            let clientActivityId = UUID().uuidString
            
            let feedbackConfig = FeedbackConfig(
                feedbackData: Binding(
                    get: { 
                        if let data = shortcutFeedbackData {
                            return data
                        } else {
                            let newData = FeedbackData()
                            Task { @MainActor in
                                shortcutFeedbackData = newData
                            }
                            return newData
                        }
                    },
                    set: { shortcutFeedbackData = $0 }
                ),
                feedbackCaptureOptions: .feedbackOnly,
                showReasons: false,
                onSubmit: {
                    Task {
                        if let feedbackData = shortcutFeedbackData {
                            try? await webService.submitFeedback(
                                clientActivityId: clientActivityId,
                                feedbackData: feedbackData
                            )
                            
                            await MainActor.run {
                                withAnimation {
                                    appState.showToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        appState.showToast = false
                                    }
                                }
                            }
                        }
                    }
                }
            )
            
            appState.feedbackConfig = feedbackConfig
        }
    }
}

struct MainView: View {

    @State private var networkState = NetworkState()

    @Environment(AuthController.self) var authController
    @Environment(OnboardingState.self) var onboardingState
    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService

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
        .overlay {
            if appState.showToast {
                FeedbackSuccessToastView()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 50)
                    .zIndex(100)
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var pendingShortcutItem: UIApplicationShortcutItem?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        AnalyticsService.shared.configure()
        
        // Setup quick actions programmatically with SF Symbol
        setupQuickActions(application: application)
        
        return true
    }
    
    private func setupQuickActions(application: UIApplication) {
        let feedbackIcon = UIApplicationShortcutIcon(systemImageName: "heart.fill")
        let feedbackShortcut = UIApplicationShortcutItem(
            type: "com.ingredicheck.feedback",
            localizedTitle: "Send me Feedback",
            localizedSubtitle: nil,
            icon: feedbackIcon,
            userInfo: nil
        )
        application.shortcutItems = [feedbackShortcut]
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        setupQuickActions(application: application)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        setupQuickActions(application: application)
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if shortcutItem.type == "com.ingredicheck.feedback" {
            NotificationCenter.default.post(name: NSNotification.Name("ShowFeedbackFromShortcut"), object: nil)
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let shortcutItem = connectionOptions.shortcutItem {
            if shortcutItem.type == "com.ingredicheck.feedback" {
                AppDelegate.pendingShortcutItem = shortcutItem
            }
        }
    }
}