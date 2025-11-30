import SwiftUI
import PostHog

@main
struct IngrediCheckApp: App {
    
    @Environment(\.scenePhase) var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        print("🔵 [FeedbackShortcut] IngrediCheckApp init - AppDelegate should be set up")
    }
    
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
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                print("🟣 [FeedbackShortcut] Scene became active")
                if let shortcutItem = appDelegate.pendingShortcutItem {
                    print("🟣 [FeedbackShortcut] Handling pending shortcut from ScenePhase: \(shortcutItem.type)")
                    if shortcutItem.type == "com.ingredicheck.feedback" {
                         NotificationCenter.default.post(name: NSNotification.Name("ShowFeedbackFromShortcut"), object: nil)
                         appDelegate.pendingShortcutItem = nil
                    }
                }
            }
        }
    }
}

struct MainView: View {

    @State private var networkState = NetworkState()
    @State private var shortcutFeedbackData: FeedbackData?
    @State private var showToast: Bool = false

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
            if showToast {
                FeedbackSuccessToastView()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 50)
                    .zIndex(100)
            }
        }
        .onAppear {
            print("🟢 [FeedbackShortcut] MainView appeared - notification listener should be active")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowFeedbackFromShortcut"))) { _ in
            print("🟢 [FeedbackShortcut] Notification received in MainView")
            handleFeedbackShortcut()
        }
    }
    
    private func handleFeedbackShortcut() {
        print("🟢 [FeedbackShortcut] handleFeedbackShortcut called")
        print("🟢 [FeedbackShortcut] Auth state: \(authController.signInState)")
        print("🟢 [FeedbackShortcut] Onboarding useCasesShown: \(onboardingState.useCasesShown)")
        print("🟢 [FeedbackShortcut] Onboarding disclaimerShown: \(onboardingState.disclaimerShown)")
        
        // Only show feedback if user is signed in (required for submission)
        guard case .signedIn = authController.signInState else {
            print("🟢 [FeedbackShortcut] User not signed in, aborting feedback")
            return
        }
        
        print("🟢 [FeedbackShortcut] User is signed in, proceeding with feedback setup")
        
        Task { @MainActor in
            print("🟢 [FeedbackShortcut] Inside MainActor task")
            @Bindable var appState = appState
            shortcutFeedbackData = FeedbackData()
            let clientActivityId = UUID().uuidString
            print("🟢 [FeedbackShortcut] Created clientActivityId: \(clientActivityId)")
            
            let feedbackConfig = FeedbackConfig(
                feedbackData: Binding(
                    get: { 
                        if let data = shortcutFeedbackData {
                            return data
                        } else {
                            // This should not happen as we set it above, but providing a safe fallback
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
                            print("🟢 [FeedbackShortcut] Submitting feedback with clientActivityId: \(clientActivityId)")
                            try? await webService.submitFeedback(
                                clientActivityId: clientActivityId,
                                feedbackData: feedbackData
                            )
                            
                            await MainActor.run {
                                withAnimation {
                                    showToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        showToast = false
                                    }
                                }
                            }
                        }
                    }
                }
            )
            
            print("🟢 [FeedbackShortcut] Setting appState.feedbackConfig")
            appState.feedbackConfig = feedbackConfig
            print("🟢 [FeedbackShortcut] appState.feedbackConfig set. Current value: \(appState.feedbackConfig != nil ? "non-nil" : "nil")")
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    var pendingShortcutItem: UIApplicationShortcutItem?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("🔵 [FeedbackShortcut] didFinishLaunchingWithOptions called")
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
        print("🔵 [FeedbackShortcut] Quick actions setup complete with heart.fill icon")
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("🔵 [FeedbackShortcut] configurationForConnecting called")
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        print("🔵 [FeedbackShortcut] performActionFor called with type: \(shortcutItem.type)")
        // With SceneDelegate, this might not be called, but keeping it as fallback
        if shortcutItem.type == "com.ingredicheck.feedback" {
            NotificationCenter.default.post(name: NSNotification.Name("ShowFeedbackFromShortcut"), object: nil)
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("🔵 [FeedbackShortcut] applicationWillEnterForeground called")
        setupQuickActions(application: application)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("🔵 [FeedbackShortcut] applicationDidBecomeActive called")
        setupQuickActions(application: application)
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        print("🟠 [FeedbackShortcut] SceneDelegate performActionFor called with type: \(shortcutItem.type)")
        if shortcutItem.type == "com.ingredicheck.feedback" {
            print("🟠 [FeedbackShortcut] Posting notification from SceneDelegate")
            NotificationCenter.default.post(name: NSNotification.Name("ShowFeedbackFromShortcut"), object: nil)
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("🟠 [FeedbackShortcut] SceneDelegate willConnectTo called")
        if let shortcutItem = connectionOptions.shortcutItem {
            print("🟠 [FeedbackShortcut] Shortcut found in connectionOptions: \(shortcutItem.type)")
            if shortcutItem.type == "com.ingredicheck.feedback" {
                // Delay slightly to ensure UI is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowFeedbackFromShortcut"), object: nil)
                }
            }
        }
    }
}