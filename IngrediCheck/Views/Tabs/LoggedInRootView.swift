
import SwiftUI

enum TabScreen: Hashable, Identifiable, CaseIterable {
    
    case home
    case scan
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
        case .scan:
            Label("Scan", systemImage: "barcode.viewfinder")
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
        case .scan:
            ScanTab()
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
    var scanRoutes: [CapturedItem] = []
    var activeSheet: Sheets?
}

struct LoggedInRootView: View {

    @State private var activeTab: TabScreen = .home
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
                activeTab = .scan
            }
        }
        .sheet(item: $appState.activeSheet) { sheet in
            switch sheet {
            case .captureFeedback(let onSubmit):
                FeedbackView(onSubmit: onSubmit)
                    .presentationDetents([.medium])
            }
        }
    }
    
    var selectedTab: Binding<TabScreen> {
        return .init {
            return activeTab
        } set: { newValue in
            if newValue == activeTab {
                print("Same tab tapped, going to top of stack")
                appState.scanRoutes = []
            }
            activeTab = newValue
        }
    }
}
