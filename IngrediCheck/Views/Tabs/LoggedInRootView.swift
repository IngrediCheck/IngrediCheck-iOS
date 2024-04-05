
import SwiftUI

enum TabScreen: Hashable, Identifiable, CaseIterable {
    
    case home
    case history

    var id: TabScreen { self }
}

extension TabScreen {
    
    @ViewBuilder
    var label: some View {
        switch self {
        case .home:
            Label("Home", systemImage: "house")
        case .history:
            Label("History", systemImage: "list.bullet")
        }
    }
    
    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .home:
            HomeTab()
        case .history:
            HistoryTab()
        }
    }
}

enum Sheets: Identifiable {

    case settings
    case scan

    var id: String {
        switch self {
        case .settings:
            return "settings"
        case .scan:
            return "scan"
        }
    }
}

@Observable class CheckTabState {
    var routes: [CapturedItem] = []
    var capturedImages: [ProductImage] = []
    var feedbackConfig: FeedbackConfig?
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
    @MainActor var historyTabState = HistoryTabState()
    @MainActor var feedbackConfig: FeedbackConfig?
}

@MainActor struct LoggedInRootView: View {

    @Environment(WebService.self) var webService
    @Environment(AppState.self) var appState
    @Environment(UserPreferences.self) var userPreferences

    var body: some View {
        @Bindable var appState = appState
        VStack {
            appState.activeTab.destination
        }
        .tabViewStyle(PageTabViewStyle())
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Spacer()

                    Button(action: {
                        withAnimation {
                            appState.activeTab = .home
                        }
                    }) {
                        TabScreen.home.label
                    }
                    .foregroundStyle(appState.activeTab == .home ? .paletteAccent : .gray)

                    Spacer()
                    Spacer()

                    Button(action: {
                        appState.activeSheet = .scan
                    }) {
                        ZStack {
                            Circle()
                                .fill(.paletteAccent)
                                .frame(width: 60, height: 60)

                            Image(systemName: "barcode.viewfinder")
                                .resizable()
                                .scaledToFit()
                                .padding()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.white)
                        }
                    }
                    .offset(y: 8)

                    Spacer()
                    Spacer()

                    Button(action: {
                        refreshHistory()
                        withAnimation {
                            appState.activeTab = .history
                        }
                    }) {
                        TabScreen.history.label
                    }
                    .foregroundStyle(appState.activeTab == .history ? .paletteAccent : .gray)
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            if userPreferences.startScanningOnAppStart
               &&
               !userPreferences.preferences.isEmpty {
                appState.activeSheet = .scan
            }
        }
        .sheet(item: $appState.activeSheet) { sheet in
            switch sheet {
            case .settings:
                SettingsSheet()
                    .environment(userPreferences)
            case .scan:
                CheckTab()
                    .environment(userPreferences)
            }
        }
        .sheet(item: $appState.feedbackConfig) { feedbackConfig in
            let _ = print("Activating feedback sheet")
            FeedbackView(
                feedbackData: feedbackConfig.feedbackData,
                feedbackCaptureOptions: feedbackConfig.feedbackCaptureOptions,
                onSubmit: feedbackConfig.onSubmit
            )
            .environment(userPreferences)
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
