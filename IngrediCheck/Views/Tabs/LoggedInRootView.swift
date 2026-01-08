
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
    @MainActor var navigateToSettings: Bool = false
}

@MainActor struct LoggedInRootView: View {

    @Environment(WebService.self) var webService
    @Environment(ScanHistoryStore.self) var scanHistoryStore
    @Environment(AppState.self) var appState
    @Environment(UserPreferences.self) var userPreferences
    @Environment(DietaryPreferences.self) var dietaryPreferences
    @Environment(AppNavigationCoordinator.self) var coordinator
    @Environment(MemojiStore.self) var memojiStore
    @State private var lastPresentedSheet: Sheets? = nil
    
    // Provide Onboarding state object for PersistentBottomSheet and other consumers
    @StateObject private var onboarding = Onboarding(onboardingFlowtype: .individual)

    var body: some View {
        @Bindable var appState = appState
        @Bindable var coordinator = coordinator

        ZStack(alignment: .bottom) {
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

            // Dim background when certain sheets are presented (e.g., Invite)
            Group {
                switch coordinator.currentBottomSheetRoute {
                case .wouldYouLikeToInvite(_, _):
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                default:
                    EmptyView()
                }
            }

            PersistentBottomSheet()
        }
        .environment(coordinator)
        .environmentObject(onboarding)
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
            case .settings:
                SettingsSheet()
                    .environment(userPreferences)
                    .environment(memojiStore)
                    .environment(coordinator)
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
            // Load scan history via store (single source of truth)
            await scanHistoryStore.loadHistory(limit: 20, offset: 0, forceRefresh: true)

            // Sync to AppState for backwards compatibility
            await MainActor.run {
                appState.listsTabState.scans = scanHistoryStore.scans
            }

            // Load favorites
            if let listItems = try? await webService.getFavorites() {
                await MainActor.run {
                    appState.listsTabState.listItems = listItems
                }
            }
        }
    }
}
