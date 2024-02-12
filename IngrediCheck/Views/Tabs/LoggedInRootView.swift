
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

@Observable class NavigationRoutes {
    var scanRoutes: [CapturedItem] = []
}

struct LoggedInRootView: View {

    @State private var activeTab: TabScreen = .home
    @State private var userPreferences: UserPreferences = UserPreferences()
    @State private var navigationRoutes = NavigationRoutes()

    var body: some View {
        TabView(selection: selectedTab) {
            ForEach(TabScreen.allCases) { screen in
                screen.destination
                    .tag(screen as TabScreen?)
                    .tabItem { screen.label }
            }
        }
        .environment(userPreferences)
        .environment(navigationRoutes)
        .tint(.paletteAccent)
        .onAppear {
            if !userPreferences.preferences.isEmpty {
                activeTab = .scan
            }
        }
    }
    
    var selectedTab: Binding<TabScreen> {
        return .init {
            return activeTab
        } set: { newValue in
            if newValue == activeTab {
                print("Same tab tapped, going to top of stack")
                navigationRoutes.scanRoutes = []
            }
            activeTab = newValue
        }
    }
}
