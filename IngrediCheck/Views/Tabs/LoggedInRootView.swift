
import SwiftUI

enum TabScreen {
    case home
    case lists
}

enum Sheets: Identifiable, Equatable {

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
    var scanId: String?  // For photo scans - generated when first image is captured
    var feedbackConfig: FeedbackConfig?
}

enum HistoryRouteItem: Hashable {
    case scan(DTO.Scan)
    case listItem(DTO.ListItem)
    case favoritesAll
    case recentScansAll
}

struct ListsTabState {
    var routes: [HistoryRouteItem] = []
    var scans: [DTO.Scan]? = nil
    var listItems: [DTO.ListItem]? = nil
}

@Observable class AppState {
    @MainActor var activeSheet: Sheets?
    @MainActor var activeTab: TabScreen = .home
    @MainActor var listsTabState = ListsTabState()
    @MainActor var feedbackConfig: FeedbackConfig?
}

@MainActor struct LoggedInRootView: View {

    @Environment(WebService.self) var webService
    @Environment(AppState.self) var appState
    @Environment(UserPreferences.self) var userPreferences
    @Environment(DietaryPreferences.self) var dietaryPreferences
    @State private var lastPresentedSheet: Sheets? = nil

    var body: some View {
        @Bindable var appState = appState
        VStack {
            switch (appState.activeTab) {
            case .home:
                HomeTab()
            case .lists:
                ListsTab()
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
               !dietaryPreferences.preferences.isEmpty {
                appState.activeSheet = .scan
            }
            refreshHistory()
        }
        .sheet(item: $appState.activeSheet) { sheet in
            switch sheet {
            case .scan:
                CheckTab()
                    .environment(userPreferences)
            default:
                EmptyView()
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
        .onChange(of: appState.activeSheet) { newSheet in
            // When the scan sheet is closed, refresh history so Home/Lists
            // recent scans reflect the latest product immediately.
            if lastPresentedSheet == .scan && newSheet == nil {
                refreshHistory()
            }
            lastPresentedSheet = newSheet
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
                if appState.activeTab == .lists {
                    appState.listsTabState.routes = []
                } else {
                    appState.activeTab = .lists
                }
            }
        }) {
            Circle()
                .fill(appState.activeTab == .lists ? .paletteAccent.opacity(0.2) : .clear)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(appState.activeTab == .lists ? .paletteAccent : .gray)
                }
        }
        Spacer()
    }

    private func refreshHistory() {
        Task {
            if let historyResponse = try? await webService.fetchScanHistory(limit: 20, offset: 0) {
                await MainActor.run {
                    appState.listsTabState.scans = historyResponse.scans
                }
            }
            if let listItems = try? await webService.getFavorites() {
                await MainActor.run {
                    appState.listsTabState.listItems = listItems
                }
            }
        }
    }
}
