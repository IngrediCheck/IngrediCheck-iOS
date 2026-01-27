
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

    // MARK: - Single Root NavigationStack

    /// The unified navigation path for the entire app.
    /// All navigation flows through this path via `navigate(to:)`.
    @MainActor var navigationPath = NavigationPath()

    /// Tracks the current navigation route for FAB visibility and context.
    /// Updated when navigating via `navigate(to:)`.
    @MainActor var currentRoute: AppRoute? = nil

    /// ScanId to scroll to when returning to ScanCameraView (e.g., from ProductDetail "Add Image")
    @MainActor var scrollToScanId: String?

    /// Tracks whether ScanCameraView is currently in the navigation stack.
    /// Used by ProductDetailView to decide whether to pop back or push new camera.
    @MainActor var hasCameraInStack: Bool = false

    /// Tracks whether ScanCameraView is currently the visible/active view.
    /// Set by ScanCameraView on appear/disappear. Used by AIBot FAB visibility logic.
    @MainActor var isInScanCameraView: Bool = false

    /// The currently displayed scan ID (set by ProductDetailView on appear).
    /// Used by AIBot FAB to provide context regardless of navigation method.
    @MainActor var displayedScanId: String? = nil

    /// The currently displayed analysis ID (set by ProductDetailView on appear).
    /// Used by AIBot FAB to provide context for analysis feedback.
    @MainActor var displayedAnalysisId: String? = nil

    /// Navigate to a route by pushing it onto the navigation stack.
    @MainActor func navigate(to route: AppRoute) {
        currentRoute = route
        navigationPath.append(route)
    }

    /// Pop the top route from the navigation stack.
    @MainActor func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
        if navigationPath.isEmpty {
            currentRoute = nil
        }
    }

    /// Pop all routes, returning to the root view.
    @MainActor func navigateToRoot() {
        navigationPath = NavigationPath()
        currentRoute = nil
    }

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

        NavigationStack(path: $appState.navigationPath) {
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
            .navigationDestination(for: AppRoute.self) { route in
                destinationView(for: route)
            }
            .navigationDestination(for: HistoryRouteItem.self) { item in
                historyDestinationView(for: item)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if shouldShowAIBotFAB {
                AIBotFAB(
                    onTap: { presentAIBotWithContext() },
                    showPromptBubble: coordinator.showFeedbackPromptBubble,
                    onPromptTap: { coordinator.dismissFeedbackPrompt(openChat: true) },
                    onPromptDismiss: { coordinator.dismissFeedbackPrompt(openChat: false) }
                )
                .padding(.trailing, 20)
//                .padding(.bottom, 100)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: shouldShowAIBotFAB)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: coordinator.showFeedbackPromptBubble)
        .tint(Color(hex: "#303030"))
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
        .onChange(of: appState.activeTab) { _, _ in
            // Reset navigation to root when switching tabs
            appState.navigateToRoot()
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
            // Navigate to ScanCameraView via push navigation (Single Root NavigationStack)
            appState.navigate(to: .scanCamera(initialMode: nil, initialScanId: nil))
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

    // MARK: - AIBot FAB

    private var shouldShowAIBotFAB: Bool {
        // Don't show on root (HomeView has its own AIBot buttons)
        guard !appState.navigationPath.isEmpty else { return false }

        // Hide on camera (check if current route is scanCamera)
        if let currentRoute = appState.currentRoute {
            switch currentRoute {
            case .scanCamera:
                return false  // Hide during scanning
            default:
                break
            }
        }

        // Show on all detail screens (AppRoute or HistoryRouteItem navigation)
        return true
    }

    private func presentAIBotWithContext() {
        // Dismiss any feedback prompt bubble first and open chat with pending context
        // (feedback context includes analysisId, ingredientName, feedbackId as needed)
        if coordinator.showFeedbackPromptBubble {
            coordinator.dismissFeedbackPrompt(openChat: true)
            return
        }

        // Try to get context from AppRoute navigation
        // Only pass scanId for product_scan context (not analysisId - that's for feedback)
        if let currentRoute = appState.currentRoute {
            switch currentRoute {
            case .productDetail(let scanId, _):
                coordinator.showAIBotSheetWithContext(scanId: scanId)
                return
            default:
                break
            }
        }

        // Fallback: Check if ProductDetailView has set displayedScanId (for HistoryRouteItem navigation)
        // Only pass scanId for product_scan context
        if let displayedScanId = appState.displayedScanId {
            coordinator.showAIBotSheetWithContext(scanId: displayedScanId)
            return
        }

        // No product context available - open chat with home context
        coordinator.showAIBotSheet()
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

    // MARK: - Navigation Destination Builder

    /// Builds the destination view for each AppRoute.
    /// All navigated views receive proper environment objects.
    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .productDetail(let scanId, let initialScan):
            ProductDetailView(
                scanId: scanId,
                initialScan: initialScan,
                presentationSource: .pushNavigation
            )

        case .scanCamera(let initialMode, let initialScanId):
            ScanCameraView(presentationSource: .pushNavigation)
                .environment(userPreferences)
                .environment(appState)

        case .favoritesAll:
            FavoritesPageView()
                .environment(appState)

        case .recentScansAll:
            RecentScansPageView()
                .environment(appState)
                .environment(scanHistoryStore)

        case .favoriteDetail(let item):
            // Show product detail for a favorite list item
            ProductDetailView(
                scanId: item.list_item_id,
                initialScan: nil,
                presentationSource: .pushNavigation
            )

        case .settings:
            SettingsContentView()
                .environment(userPreferences)
                .environment(memojiStore)
                .environment(coordinator)

        case .manageFamily:
            ManageFamilyView()
                .environment(coordinator)

        case .editableCanvas(let targetSection):
            UnifiedCanvasView(mode: .editing, targetSectionName: targetSection)
                .environment(memojiStore)
                .environment(coordinator)
        }
    }

    // MARK: - History Navigation Destination Builder

    /// Builds the destination view for HistoryRouteItem navigation.
    /// This supports legacy navigation from ListsTab and related views.
    @ViewBuilder
    private func historyDestinationView(for item: HistoryRouteItem) -> some View {
        switch item {
        case .scan(let scan):
            let product = scan.toProduct()
            let recommendations = scan.analysis_result?.toIngredientRecommendations()
            ProductDetailView(
                scanId: scan.id,
                initialScan: scan,
                product: product,
                matchStatus: scan.toProductRecommendation(),
                ingredientRecommendations: recommendations,
                isPlaceholderMode: false,
                presentationSource: .pushNavigation
            )

        case .listItem(let item):
            FavoriteItemDetailView(item: item)

        case .favoritesAll:
            FavoritesPageView()
                .environment(appState)

        case .recentScansAll:
            RecentScansPageView()
                .environment(appState)
                .environment(scanHistoryStore)
        }
    }
}
