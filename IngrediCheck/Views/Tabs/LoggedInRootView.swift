
import SwiftUI

enum TabScreen {
    case home
    case history
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
    @Environment(DietaryPreferences.self) var dietaryPreferences

    var body: some View {
        @Bindable var appState = appState
        VStack {
            switch (appState.activeTab) {
            case .home:
                HomeTab()
            case .history:
                HistoryTab()
            }
        }
        .tabViewStyle(PageTabViewStyle())
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                tabButtons
            }
        }
        .onAppear {
            if userPreferences.startScanningOnAppStart
               &&
                // TODO: preferences may not be updated before onAppear here.
               !dietaryPreferences.preferences.isEmpty {
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
    
    @ViewBuilder
    private var tabButtons: some View {
        Spacer()
        Button(action: {
            withAnimation {
                appState.activeTab = .home
            }
        }) {
            Circle()
                .fill(appState.activeTab == .home ? .paletteAccent.opacity(0.2) : .clear)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "house")
                        .foregroundStyle(appState.activeTab == .home ? .paletteAccent : .gray)
                }
        }
        Spacer()
        Spacer()
        Button(action: {
            appState.activeSheet = .scan
        }) {
            ZStack {
                Circle()
                    .fill(.paletteAccent)
                    .frame(width: 50, height: 50)

                Image(systemName: "barcode.viewfinder")
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white)
            }
        }
        .offset(y: 5)
        Spacer()
        Spacer()
        Button(action: {
            refreshHistory()
            withAnimation {
                appState.activeTab = .history
            }
        }) {
            Circle()
                .fill(appState.activeTab == .history ? .paletteAccent.opacity(0.2) : .clear)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(appState.activeTab == .history ? .paletteAccent : .gray)
                }
        }
        Spacer()
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
