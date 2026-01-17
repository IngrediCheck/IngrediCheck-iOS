
import SwiftUI
import os

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

    @MainActor func setHistoryItemFavorited(clientActivityId: String, favorited: Bool) {
        // Legacy function for backwards compatibility with old HistoryItem API
        // The new API uses scans with id instead of clientActivityId
        // Try to find matching scan by id (clientActivityId might be a scan id)
        guard var scans = listsTabState.scans else { return }
        guard let idx = scans.firstIndex(where: { $0.id == clientActivityId }) else {
            // If not found, this might be a legacy HistoryItem - no-op for now
            // The new API handles favorites via toggleFavorite(scanId:) in WebService
            return
        }
        
        // Update the scan's is_favorited field
        var updatedScan = scans[idx]
        // Since is_favorited is let, we need to create a new Scan with updated value
        let newScan = DTO.Scan(
            id: updatedScan.id,
            scan_type: updatedScan.scan_type,
            barcode: updatedScan.barcode,
            state: updatedScan.state,
            product_info: updatedScan.product_info,
            product_info_source: updatedScan.product_info_source,
            product_info_vote: updatedScan.product_info_vote,
            analysis_result: updatedScan.analysis_result,
            images: updatedScan.images,
            latest_guidance: updatedScan.latest_guidance,
            created_at: updatedScan.created_at,
            last_activity_at: updatedScan.last_activity_at,
            is_favorited: favorited,
            analysis_id: updatedScan.analysis_id
        )
        scans[idx] = newScan
        listsTabState.scans = scans
    }
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
            // Note: Auto-scan on app start is now handled in HomeView
            // to open ScanCameraView directly instead of CheckTab
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
            let _ = Log.debug("LoggedInRootView", "Activating feedback sheet")
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
        Log.debug("LoggedInRootView", "📋 refreshHistory called")
        Task {
            Log.debug("LoggedInRootView", "📋 refreshHistory Task started, calling loadHistory")
            // Load scan history via store (single source of truth)
            await scanHistoryStore.loadHistory(limit: 20, offset: 0, forceRefresh: true)
            Log.debug("LoggedInRootView", "📋 refreshHistory loadHistory completed")

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
