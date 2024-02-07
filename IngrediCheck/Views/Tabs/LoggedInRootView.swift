
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

struct LoggedInRootView: View {

    @State private var selectedTab: TabScreen = .home
    @State private var userPreferences: UserPreferences = UserPreferences()

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(TabScreen.allCases) { screen in
                screen.destination
                    .tag(screen as TabScreen?)
                    .tabItem { screen.label }
            }
        }
        .environment(userPreferences)
        .tint(.paletteAccent)
        .onAppear {
            if !userPreferences.preferences.isEmpty {
                selectedTab = .scan
            }
        }
    }
}
