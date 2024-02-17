
import SwiftUI

enum TabScreen: Hashable, Identifiable, CaseIterable {
    
    case home
    case check
    case history
    case settings

    var id: TabScreen { self }
}

extension TabScreen {
    
    @ViewBuilder
    var label: some View {
        switch self {
        case .home:
            Label("Home", systemImage: "house.fill")
        case .check:
            Label("Check", systemImage: "barcode.viewfinder")
        case .history:
            Label("History", systemImage: "clock.arrow.circlepath")
        case .settings:
            Label("Settings", systemImage: "gearshape.fill")
        }
    }
    
    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .home:
            HomeTab()
        case .check:
            CheckTab()
        case .history:
            HistoryTab()
        case .settings:
            SettingsTab()
        }
    }
}

enum Sheets: Identifiable {

    case captureFeedback(onSubmit: (String) -> Void)

    var id: String {
        switch self {
        case .captureFeedback:
            return "captureFeedback"
        }
    }
}

@Observable class AppState {
    var checkRoutes: [CapturedItem] = []
    var activeSheet: Sheets?
    var activeTab: TabScreen = .home
}

struct LoggedInRootView: View {

    @State private var userPreferences: UserPreferences = UserPreferences()
    @State private var appState = AppState()

    var body: some View {
        TabView(selection: selectedTab) {
            ForEach(TabScreen.allCases) { screen in
                screen.destination
                    .tag(screen as TabScreen?)
                    .tabItem { screen.label }
            }
        }
        .environment(userPreferences)
        .environment(appState)
        .onAppear {
            if !userPreferences.preferences.isEmpty {
                appState.activeTab = .check
            }
        }
        .sheet(item: $appState.activeSheet) { sheet in
            switch sheet {
            case .captureFeedback(let onSubmit):
                FeedbackView(onSubmit: onSubmit)
                    .presentationDetents([.medium])
                    .presentationBackground(.regularMaterial)
            }
        }
    }
    
    var selectedTab: Binding<TabScreen> {
        return .init {
            return appState.activeTab
        } set: { newValue in
            if newValue == appState.activeTab {
                if case .check = newValue {
                    appState.checkRoutes = []
                }
            }
            appState.activeTab = newValue
        }
    }
}
