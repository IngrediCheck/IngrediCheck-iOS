
import SwiftUI

enum TabScreen: Hashable, Identifiable, CaseIterable {
    
    case home
    case check
    case history

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
        }
    }
}

enum Sheets: Identifiable {

    case feedback(FeedbackConfig)
    case settings

    var id: String {
        switch self {
        case .feedback:
            return "feedback"
        case .settings:
            return "settings"
        }
    }
}

struct CheckTabState {
    var routes: [CapturedItem] = []
    var capturedImages: [ProductImage] = []
}

enum HistoryRouteItem: Hashable {
    case historyItem(DTO.HistoryItem)
    case listItem(DTO.ListItem)
}

struct HistoryTabState {
    var routes: [HistoryRouteItem] = []
    var historyItems: [DTO.HistoryItem]? = nil
    var listItems: [DTO.ListItem]? = nil
}

@Observable class AppState {
    @MainActor var activeSheet: Sheets?
    @MainActor var activeTab: TabScreen = .home
    @MainActor var checkTabState = CheckTabState()
    @MainActor var historyTabState = HistoryTabState()
}

@MainActor struct LoggedInRootView: View {

    @State private var userPreferences: UserPreferences = UserPreferences()
    @State private var appState = AppState()
    
    @Environment(WebService.self) var webService

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
            case .feedback(let feedbackConfig):
                FeedbackView(
                    feedbackData: feedbackConfig.feedbackData,
                    feedbackCaptureOptions: feedbackConfig.feedbackCaptureOptions,
                    onSubmit: feedbackConfig.onSubmit
                )
                .environment(userPreferences)
            case .settings:
                SettingsSheet()
                    .environment(userPreferences)
            }
        }
    }
    
    @MainActor var selectedTab: Binding<TabScreen> {
        return .init {
            return appState.activeTab
        } set: { newValue in
            if newValue == appState.activeTab {
                switch newValue {
                case .check:
                    appState.checkTabState.routes = []
                case .history:
                    appState.historyTabState.routes = []
                default:
                    break
                }
            } else {
                switch newValue {
                case .history:
                    refreshHistory()
                default:
                    break
                }
            }
            appState.activeTab = newValue
        }
    }
    
    private func refreshHistory() {
        Task {
            if let history = try? await webService.fetchHistory() {
                await MainActor.run {
                    appState.historyTabState.historyItems = history
                }
            }
            if let listItems = try? await webService.getFavorites() {
                await MainActor.run {
                    appState.historyTabState.listItems = listItems
                }
            }
        }
    }
}
