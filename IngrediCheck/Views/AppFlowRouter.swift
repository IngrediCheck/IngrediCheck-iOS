import SwiftUI

/// Routes between production and preview flows based on configuration
struct AppFlowRouter: View {
    @State private var webService = WebService()
    @State private var scanHistoryStore: ScanHistoryStore
    @State private var dietaryPreferences = DietaryPreferences()
    @State private var userPreferences: UserPreferences = UserPreferences()
    @State private var appState = AppState()
    @State private var onboardingState = OnboardingState()
    @State private var authController = AuthController()
    @State private var familyStore = FamilyStore()
    @State private var coordinator = AppNavigationCoordinator(initialRoute: .heyThere)
    @State private var memojiStore = MemojiStore()
    @State private var appResetID = UUID()

    init() {
        let ws = WebService()
        _webService = State(initialValue: ws)
        _scanHistoryStore = State(initialValue: ScanHistoryStore(webService: ws))
    }
    
    var body: some View {
        Group {
            if Config.usePreviewFlow {
                PreviewFlowView()
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
            } else {
                ProductionFlowView()
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
            }
        }
        .id(appResetID)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AppDidReset"))) { _ in
            appResetID = UUID()
            let ws = WebService()
            webService = ws
            scanHistoryStore = ScanHistoryStore(webService: ws)
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
        #if DEBUG
        if let qaState = QALaunchOverrides.microcopyQAState {
            RootContainerView(restoredState: qaState)
                .preferredColorScheme(.light)
        } else if ProcessInfo.processInfo.arguments.contains("--qa-skip-welcome") {
            RootContainerView(restoredState: nil)
                .preferredColorScheme(.light)
        } else {
            SplashScreen()
                .preferredColorScheme(.light)
        }
        #else
        SplashScreen()
            .preferredColorScheme(.light)
        #endif
    }
}

#Preview {
    AppFlowRouter()
}

#if DEBUG
private enum QALaunchOverrides {
    static var microcopyQAState: (canvas: CanvasRoute, sheet: BottomSheetRoute)? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--microcopy-qa") else { return nil }

        let canvasRaw = value(after: "--qa-canvas", in: args) ?? "heyThere"
        let sheetRaw = value(after: "--qa-sheet", in: args) ?? "alreadyHaveAnAccount"

        guard let canvas = canvasRoute(from: canvasRaw),
              let sheet = sheetRoute(from: sheetRaw) else {
            return nil
        }

        return (canvas: canvas, sheet: sheet)
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else { return nil }
        return args[idx + 1]
    }

    private static func canvasRoute(from raw: String) -> CanvasRoute? {
        switch raw {
        case "heyThere":
            return .heyThere
        case "blankScreen":
            return .blankScreen
        case "letsGetStarted":
            return .letsGetStarted
        case "letsMeetYourIngrediFam":
            return .letsMeetYourIngrediFam
        case "home":
            return .home
        case "whyWeNeedThesePermissions":
            return .whyWeNeedThesePermissions
        default:
            return nil
        }
    }

    private static func sheetRoute(from raw: String) -> BottomSheetRoute? {
        switch raw {
        case "alreadyHaveAnAccount":
            return .alreadyHaveAnAccount
        case "welcomeBack":
            return .welcomeBack
        case "doYouHaveAnInviteCode":
            return .doYouHaveAnInviteCode
        case "enterInviteCode":
            return .enterInviteCode
        case "whosThisFor":
            return .whosThisFor
        case "homeDefault":
            return .homeDefault
        case "quickAccessNeeded":
            return .quickAccessNeeded
        case "loginToContinue":
            return .loginToContinue
        default:
            return nil
        }
    }
}
#endif
