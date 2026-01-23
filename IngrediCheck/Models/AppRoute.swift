import Foundation

/// Unified navigation routes for the app's Single Root NavigationStack architecture.
/// All navigation throughout the app flows through these routes via `appState.navigate(to:)`.
enum AppRoute: Hashable {

    // MARK: - Product & Scan

    /// Navigate to product detail view
    /// - Parameters:
    ///   - scanId: The unique scan identifier
    ///   - initialScan: Optional pre-loaded scan data (avoids refetch if available)
    case productDetail(scanId: String, initialScan: DTO.Scan?)

    /// Navigate to scan camera
    /// - Parameters:
    ///   - initialMode: Optional camera mode (.scanner or .photo)
    ///   - initialScanId: Optional scan ID to continue an existing scan
    case scanCamera(initialMode: CameraMode?, initialScanId: String?)

    // MARK: - Lists & History

    /// Navigate to all favorites page
    case favoritesAll

    /// Navigate to all recent scans page
    case recentScansAll

    /// Navigate to favorite item detail
    /// - Parameter item: The list item to display
    case favoriteDetail(item: DTO.ListItem)

    // MARK: - Settings & Profile

    /// Navigate to settings screen
    case settings

    /// Navigate to manage family screen
    case manageFamily

    /// Navigate to editable canvas (memoji/avatar editor)
    /// - Parameter targetSection: Optional section to scroll to
    case editableCanvas(targetSection: String?)

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        switch self {
        case .productDetail(let scanId, _):
            hasher.combine("productDetail")
            hasher.combine(scanId)
        case .scanCamera(let mode, let scanId):
            hasher.combine("scanCamera")
            hasher.combine(mode.map { $0 == .scanner ? "scanner" : "photo" })
            hasher.combine(scanId)
        case .favoritesAll:
            hasher.combine("favoritesAll")
        case .recentScansAll:
            hasher.combine("recentScansAll")
        case .favoriteDetail(let item):
            hasher.combine("favoriteDetail")
            hasher.combine(item.list_item_id)
        case .settings:
            hasher.combine("settings")
        case .manageFamily:
            hasher.combine("manageFamily")
        case .editableCanvas(let section):
            hasher.combine("editableCanvas")
            hasher.combine(section)
        }
    }

    static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        switch (lhs, rhs) {
        case (.productDetail(let lId, _), .productDetail(let rId, _)):
            return lId == rId
        case (.scanCamera(let lMode, let lId), .scanCamera(let rMode, let rId)):
            return lMode.map { $0 == .scanner ? "scanner" : "photo" } == rMode.map { $0 == .scanner ? "scanner" : "photo" } && lId == rId
        case (.favoritesAll, .favoritesAll):
            return true
        case (.recentScansAll, .recentScansAll):
            return true
        case (.favoriteDetail(let lItem), .favoriteDetail(let rItem)):
            return lItem.list_item_id == rItem.list_item_id
        case (.settings, .settings):
            return true
        case (.manageFamily, .manageFamily):
            return true
        case (.editableCanvas(let lSection), .editableCanvas(let rSection)):
            return lSection == rSection
        default:
            return false
        }
    }
}
