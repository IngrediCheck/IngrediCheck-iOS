
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

    /// Flag to trigger scan history refresh from other views (e.g., after food preferences change).
    /// Set to true by views that modify data affecting scan results, observed by HomeView.
    @MainActor var needsScanHistoryRefresh: Bool = false

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
        guard var scans = listsTabState.scans else { return }
        guard let idx = scans.firstIndex(where: { $0.id == clientActivityId }) else {
            return
        }

        let updatedScan = scans[idx]
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
