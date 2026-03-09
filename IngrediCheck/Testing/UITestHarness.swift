import Foundation

private let uiTestEveryoneOwnerKey = "Everyone"

enum UITestAuthProvider: String {
    case guest
    case google
    case apple
}

enum UITestAuthOutcome: String {
    case success
    case failure
}

struct UITestPermissions {
    let cameraAuthorized: Bool
    let notificationsAuthorized: Bool
}

struct UITestTipProduct: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let price: String
}

enum UITestTipPurchaseOutcome {
    case success(message: String)
    case cancelled(message: String)
    case failed(message: String)
}

enum UITestScenario: String {
    case authSignIn
    case authGoogle
    case authGoogleFailure
    case authApple
    case authAppleFailure
    case onboardingIndividual
    case onboardingFamily
    case joinFamily
    case home
    case settings
    case manageFamily
    case foodNotes
    case scanBarcode
    case scanPhoto
    case productDetail
    case favorites
    case recentScans
    case chat
    case permissions
    case tipJar
    case support
    case productDetailFavorited
    case productDetailStale
    case recentScansEmpty
    case settingsGuest
}

struct UITestFixture {
    let scenario: UITestScenario
    let restoredState: (canvas: CanvasRoute, sheet: BottomSheetRoute)?
    let requiresSession: Bool
    let launchesWithCompletedOnboarding: Bool
    let marksOnboardingCompleted: Bool
    let authProvider: UITestAuthProvider?
    let googleOutcome: UITestAuthOutcome
    let appleOutcome: UITestAuthOutcome
    let homeRoute: AppRoute?
    let openSettingsSheet: Bool
    let startScanningOnAppStart: Bool
    let family: Family?
    let selectedMemberId: UUID?
    let foodNotesAll: WebService.FoodNotesAllResponse?
    let foodNotesSummary: DTO.FoodNotesSummaryResponse?
    let permissions: UITestPermissions
    let scans: [DTO.Scan]
    let stats: DTO.StatsResponse
    let favorites: [DTO.ListItem]
    let chatReplies: [String: String]
    let tipProducts: [UITestTipProduct]
    let tipPurchaseOutcome: UITestTipPurchaseOutcome
    let shareMessage: String?
}

enum UITestHarness {
    static let launchArgument = "--ui-test-mode"
    static let scenarioArgumentPrefix = "--ui-test-scenario="
    private static let scenarioEnvironmentKey = "IC_UI_TEST_SCENARIO"

    static var isEnabled: Bool {
#if DEBUG && targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(launchArgument) {
            return true
        }
        if let rawValue = arguments.first(where: { $0.hasPrefix("\(launchArgument)=") })?
            .split(separator: "=", maxSplits: 1)
            .last
        {
            return isTruthy(String(rawValue))
        }
        return false
#else
        false
#endif
    }

    static var scenario: UITestScenario? {
        guard isEnabled else { return nil }
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(scenarioArgumentPrefix) }) {
            let rawValue = normalizedScenarioValue(String(argument.dropFirst(scenarioArgumentPrefix.count)))
            if let scenario = UITestScenario(rawValue: rawValue) {
                return scenario
            }
        }
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--ui-test-scenario"),
           ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
            let rawValue = normalizedScenarioValue(ProcessInfo.processInfo.arguments[index + 1])
            if let scenario = UITestScenario(rawValue: rawValue) {
                return scenario
            }
        }
        if let rawValue = ProcessInfo.processInfo.environment[scenarioEnvironmentKey],
           let scenario = UITestScenario(rawValue: normalizedScenarioValue(rawValue)) {
            return scenario
        }
        return .home
    }

    static var fixture: UITestFixture? {
        guard let scenario else { return nil }
        return UITestFixtures.fixture(for: scenario)
    }

    static func prepareRuntime() async {
        guard let fixture else { return }
        await UITestRuntime.shared.reset(with: fixture)
    }

    private static func normalizedScenarioValue(_ rawValue: String) -> String {
        rawValue.split(separator: "=", maxSplits: 1).first.map(String.init) ?? rawValue
    }

    private static func isTruthy(_ rawValue: String) -> Bool {
        switch rawValue.lowercased() {
        case "1", "true", "yes", "y":
            true
        default:
            false
        }
    }
}

actor UITestRuntime {
    static let shared = UITestRuntime()

    private var fixture: UITestFixture?
    private var scansById: [String: DTO.Scan] = [:]
    private var historyOrder: [String] = []
    private var foodNotesAll: WebService.FoodNotesAllResponse?
    private var foodNotesSummary: DTO.FoodNotesSummaryResponse?
    private var conversations: [String: DTO.ConversationResponse] = [:]
    private var chatReplies: [String: String] = [:]

    func reset(with fixture: UITestFixture) {
        self.fixture = fixture
        self.foodNotesAll = fixture.foodNotesAll
        self.foodNotesSummary = fixture.foodNotesSummary
        self.chatReplies = fixture.chatReplies
        self.scansById = Dictionary(uniqueKeysWithValues: fixture.scans.map { ($0.id, $0) })
        self.historyOrder = fixture.scans.map(\.id)
        self.conversations = [:]
    }

    func currentFixture() -> UITestFixture? {
        fixture
    }

    func scanHistory(limit: Int, offset: Int) -> DTO.ScanHistoryResponse {
        let ordered = historyOrder.compactMap { scansById[$0] }
        let sliced = Array(ordered.dropFirst(offset).prefix(limit))
        return DTO.ScanHistoryResponse(
            scans: sliced,
            total: ordered.count,
            has_more: offset + sliced.count < ordered.count
        )
    }

    func stats() -> DTO.StatsResponse? {
        fixture?.stats
    }

    func favorites() -> [DTO.ListItem] {
        let favoriteIds = Set(scansById.values.filter { $0.is_favorited == true }.map(\.id))
        return fixture?.favorites.filter { favoriteIds.contains($0.list_item_id) } ?? []
    }

    func barcodeScan(barcode: String) -> DTO.Scan? {
        scansById.values.first { $0.barcode == barcode }
    }

    func photoScan() -> DTO.Scan? {
        scansById.values.first { $0.scan_type == "photo" || $0.scan_type == "barcode_plus_photo" }
    }

    func submitPhoto(scanId: String) -> DTO.SubmitImageResponse {
        let contentHash = "ui-test-photo-\(scanId)"
        let template = photoScan() ?? UITestFixtures.makeScans().first!
        let updatedScan = DTO.Scan(
            id: scanId,
            scan_type: "photo",
            barcode: nil,
            state: "done",
            product_info: template.product_info,
            product_info_source: "ui_test",
            product_info_vote: template.product_info_vote,
            analysis_result: template.analysis_result,
            images: template.images,
            latest_guidance: "Photo scan complete.",
            created_at: UITestFixtures.isoDateString(),
            last_activity_at: UITestFixtures.isoDateString(),
            error: nil,
            is_favorited: false,
            analysis_id: template.analysis_id
        )
        scansById[scanId] = updatedScan
        if !historyOrder.contains(scanId) {
            historyOrder.insert(scanId, at: 0)
        }
        return DTO.SubmitImageResponse(queued: true, queue_position: 1, content_hash: contentHash)
    }

    func scan(scanId: String) -> DTO.Scan? {
        scansById[scanId]
    }

    func toggleFavorite(scanId: String) -> Bool? {
        guard var scan = scansById[scanId] else { return nil }
        let next = !(scan.is_favorited ?? false)
        scan = DTO.Scan(
            id: scan.id,
            scan_type: scan.scan_type,
            barcode: scan.barcode,
            state: scan.state,
            product_info: scan.product_info,
            product_info_source: scan.product_info_source,
            product_info_vote: scan.product_info_vote,
            analysis_result: scan.analysis_result,
            images: scan.images,
            latest_guidance: scan.latest_guidance,
            created_at: scan.created_at,
            last_activity_at: scan.last_activity_at,
            error: scan.error,
            is_favorited: next,
            analysis_id: scan.analysis_id
        )
        scansById[scanId] = scan
        return next
    }

    func reanalyze(scanId: String) -> DTO.Scan? {
        scansById[scanId]
    }

    func submitFeedback(scanId: String?) -> DTO.Scan? {
        guard let scanId else { return nil }
        return scansById[scanId]
    }

    func updateFeedback(scanId: String?) -> DTO.Scan? {
        guard let scanId else { return nil }
        return scansById[scanId]
    }

    func fetchFoodNotesAll() -> WebService.FoodNotesAllResponse? {
        foodNotesAll
    }

    func fetchFoodNotesSummary() -> DTO.FoodNotesSummaryResponse? {
        foodNotesSummary
    }

    func updateFoodNotes(ownerKey: String?, content: [String: Any], version: Int) -> WebService.FoodNotesResponse {
        let updatedAt = UITestFixtures.isoDateString()
        let response = WebService.FoodNotesResponse(
            content: content,
            version: version + 1,
            updatedAt: updatedAt
        )

        if ownerKey == nil || ownerKey == uiTestEveryoneOwnerKey {
            foodNotesAll = WebService.FoodNotesAllResponse(
                familyNote: response,
                memberNotes: foodNotesAll?.memberNotes ?? [:]
            )
        } else {
            var memberNotes = foodNotesAll?.memberNotes ?? [:]
            memberNotes[ownerKey ?? ""] = response
            foodNotesAll = WebService.FoodNotesAllResponse(
                familyNote: foodNotesAll?.familyNote,
                memberNotes: memberNotes
            )
        }

        foodNotesSummary = DTO.FoodNotesSummaryResponse(
            summary: "Updated food notes for simulator QA.",
            generatedAt: updatedAt,
            isCached: false
        )

        return response
    }

    func chatResponse(
        message: String,
        conversationId: String?,
        contextKey: String
    ) -> (conversationId: String, turnId: String, response: String) {
        let resolvedConversationId = conversationId ?? "ui-test-conversation-\(contextKey.replacingOccurrences(of: ":", with: "-"))"
        let turnId = UUID().uuidString
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let response = chatReplies[normalized] ?? "IngrediBot simulator reply for: \(message)"

        let turnNumber = (conversations[resolvedConversationId]?.turns.count ?? 0) + 1
        let createdAt = UITestFixtures.isoDateString()

        let userTurn = DTO.ConversationTurn(
            turn_id: "\(turnId)-user",
            turn_number: turnNumber,
            user_message: message,
            assistant_response: response,
            images: [],
            created_at: createdAt
        )

        let existing = conversations[resolvedConversationId] ?? DTO.ConversationResponse(
            conversation_id: resolvedConversationId,
            turns: []
        )
        conversations[resolvedConversationId] = DTO.ConversationResponse(
            conversation_id: resolvedConversationId,
            turns: existing.turns + [userTurn]
        )

        return (resolvedConversationId, turnId, response)
    }

    func conversation(conversationId: String) -> DTO.ConversationResponse? {
        conversations[conversationId]
    }
}

private enum UITestFixtures {
    private struct SharedFixtureData {
        lazy var family: Family = UITestFixtures.makeFamily()
        lazy var scans: [DTO.Scan] = UITestFixtures.makeScans()
        lazy var stats: DTO.StatsResponse = UITestFixtures.makeStats()
        lazy var favorites: [DTO.ListItem] = UITestFixtures.makeFavorites(from: scans)
        lazy var foodNotesAll: WebService.FoodNotesAllResponse = UITestFixtures.makeFoodNotesAll(for: family)
        lazy var foodNotesSummary: DTO.FoodNotesSummaryResponse = UITestFixtures.makeFoodNotesSummary()
    }

    static func fixture(for scenario: UITestScenario) -> UITestFixture {
        var shared = SharedFixtureData()

        switch scenario {
        case .authSignIn:
            return signInSheetFixture(scenario: scenario)
        case .authGoogle:
            return authFixture(scenario: scenario, shared: &shared)
        case .authGoogleFailure:
            return signInSheetFixture(scenario: scenario, googleOutcome: .failure)
        case .authApple:
            return authFixture(scenario: scenario, shared: &shared)
        case .authAppleFailure:
            return signInSheetFixture(scenario: scenario, appleOutcome: .failure)
        case .onboardingIndividual:
            return UITestFixture(
                scenario: scenario,
                restoredState: (canvas: .heyThere, sheet: .whosThisFor),
                requiresSession: true,
                launchesWithCompletedOnboarding: false,
                marksOnboardingCompleted: false,
                authProvider: .guest,
                googleOutcome: .success,
                appleOutcome: .success,
                homeRoute: nil,
                openSettingsSheet: false,
                startScanningOnAppStart: false,
                family: nil,
                selectedMemberId: nil,
                foodNotesAll: nil,
                foodNotesSummary: nil,
                permissions: UITestPermissions(cameraAuthorized: true, notificationsAuthorized: true),
                scans: [],
                stats: emptyStats(),
                favorites: [],
                chatReplies: chatReplies(),
                tipProducts: tipProducts(),
                tipPurchaseOutcome: .success(message: "Thanks for supporting IngrediCheck"),
                shareMessage: "Share IngrediCheck"
            )
        case .onboardingFamily:
            let family = shared.family
            return UITestFixture(
                scenario: scenario,
                restoredState: (canvas: .letsMeetYourIngrediFam, sheet: .letsMeetYourIngrediFam),
                requiresSession: true,
                launchesWithCompletedOnboarding: false,
                marksOnboardingCompleted: false,
                authProvider: .guest,
                googleOutcome: .success,
                appleOutcome: .success,
                homeRoute: nil,
                openSettingsSheet: false,
                startScanningOnAppStart: false,
                family: family,
                selectedMemberId: family.selfMember.id,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                permissions: UITestPermissions(cameraAuthorized: true, notificationsAuthorized: true),
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites,
                chatReplies: chatReplies(),
                tipProducts: tipProducts(),
                tipPurchaseOutcome: .success(message: "Thanks for supporting IngrediCheck"),
                shareMessage: "Invite sent"
            )
        case .joinFamily:
            return UITestFixture(
                scenario: scenario,
                restoredState: (canvas: .heyThere, sheet: .enterInviteCode),
                requiresSession: true,
                launchesWithCompletedOnboarding: false,
                marksOnboardingCompleted: false,
                authProvider: .guest,
                googleOutcome: .success,
                appleOutcome: .success,
                homeRoute: nil,
                openSettingsSheet: false,
                startScanningOnAppStart: false,
                family: nil,
                selectedMemberId: nil,
                foodNotesAll: nil,
                foodNotesSummary: nil,
                permissions: UITestPermissions(cameraAuthorized: true, notificationsAuthorized: true),
                scans: [],
                stats: emptyStats(),
                favorites: [],
                chatReplies: chatReplies(),
                tipProducts: tipProducts(),
                tipPurchaseOutcome: .success(message: "Thanks for supporting IngrediCheck"),
                shareMessage: "Invite joined"
            )
        case .home:
            return homeFixture(
                scenario: scenario,
                homeRoute: nil,
                openSettingsSheet: false,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites
            )
        case .settings:
            return homeFixture(
                scenario: scenario,
                homeRoute: nil,
                openSettingsSheet: true,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites
            )
        case .manageFamily:
            return homeFixture(
                scenario: scenario,
                homeRoute: .manageFamily,
                openSettingsSheet: false,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites
            )
        case .foodNotes:
            return homeFixture(
                scenario: scenario,
                homeRoute: .editableCanvas(targetSection: nil),
                openSettingsSheet: false,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites
            )
        case .scanBarcode:
            return homeFixture(
                scenario: scenario,
                homeRoute: .scanCamera(initialMode: .scanner, initialScanId: nil),
                openSettingsSheet: false,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites
            )
        case .scanPhoto:
            return homeFixture(
                scenario: scenario,
                homeRoute: .scanCamera(initialMode: .photo, initialScanId: nil),
                openSettingsSheet: false,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites
            )
        case .productDetail:
            let firstScan = shared.scans[0]
            return homeFixture(
                scenario: scenario,
                homeRoute: .productDetail(scanId: firstScan.id, initialScan: firstScan),
                openSettingsSheet: false,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites
            )
        case .favorites:
            return homeFixture(
                scenario: scenario,
                homeRoute: .favoritesAll,
                openSettingsSheet: false,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites
            )
        case .recentScans:
            return homeFixture(
                scenario: scenario,
                homeRoute: .recentScansAll,
                openSettingsSheet: false,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites
            )
        case .chat:
            return homeFixture(
                scenario: scenario,
                homeRoute: nil,
                openSettingsSheet: false,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites
            )
        case .permissions:
            let family = shared.family
            return UITestFixture(
                scenario: scenario,
                restoredState: (canvas: .whyWeNeedThesePermissions, sheet: .quickAccessNeeded),
                requiresSession: true,
                launchesWithCompletedOnboarding: true,
                marksOnboardingCompleted: true,
                authProvider: .guest,
                googleOutcome: .success,
                appleOutcome: .success,
                homeRoute: nil,
                openSettingsSheet: false,
                startScanningOnAppStart: false,
                family: family,
                selectedMemberId: family.selfMember.id,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                permissions: UITestPermissions(cameraAuthorized: true, notificationsAuthorized: false),
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites,
                chatReplies: chatReplies(),
                tipProducts: tipProducts(),
                tipPurchaseOutcome: .success(message: "Thanks for supporting IngrediCheck"),
                shareMessage: "Share IngrediCheck"
            )
        case .tipJar:
            return homeFixture(
                scenario: scenario,
                homeRoute: nil,
                openSettingsSheet: true,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites,
                tipPurchaseOutcome: .success(message: "Thanks for supporting IngrediCheck")
            )
        case .support:
            return homeFixture(
                scenario: scenario,
                homeRoute: nil,
                openSettingsSheet: true,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites,
                shareMessage: "Share us tapped"
            )
        case .productDetailFavorited:
            let oreoScan = shared.scans[1] // Oreo Original (is_favorited: true)
            return homeFixture(
                scenario: scenario,
                homeRoute: .productDetail(scanId: oreoScan.id, initialScan: oreoScan),
                openSettingsSheet: false,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites
            )
        case .productDetailStale:
            let scans = shared.scans
            let dietCoke = scans[0]
            let staleDietCoke = DTO.Scan(
                id: dietCoke.id,
                scan_type: dietCoke.scan_type,
                barcode: dietCoke.barcode,
                state: dietCoke.state,
                product_info: dietCoke.product_info,
                product_info_source: dietCoke.product_info_source,
                product_info_vote: dietCoke.product_info_vote,
                analysis_result: DTO.ScanAnalysisResult(
                    id: dietCoke.analysis_result?.id,
                    overall_analysis: dietCoke.analysis_result?.overall_analysis,
                    overall_match: dietCoke.analysis_result?.overall_match,
                    ingredient_analysis: dietCoke.analysis_result?.ingredient_analysis ?? [],
                    is_stale: true,
                    vote: dietCoke.analysis_result?.vote
                ),
                images: dietCoke.images,
                latest_guidance: dietCoke.latest_guidance,
                created_at: dietCoke.created_at,
                last_activity_at: dietCoke.last_activity_at,
                error: dietCoke.error,
                is_favorited: dietCoke.is_favorited,
                analysis_id: dietCoke.analysis_id
            )
            var staleScans = scans
            staleScans[0] = staleDietCoke
            return homeFixture(
                scenario: scenario,
                homeRoute: .productDetail(scanId: staleDietCoke.id, initialScan: staleDietCoke),
                openSettingsSheet: false,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: staleScans,
                stats: shared.stats,
                favorites: shared.favorites
            )
        case .recentScansEmpty:
            return homeFixture(
                scenario: scenario,
                homeRoute: .recentScansAll,
                openSettingsSheet: false,
                family: shared.family,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                scans: [],
                stats: emptyStats(),
                favorites: []
            )
        case .settingsGuest:
            return UITestFixture(
                scenario: scenario,
                restoredState: (canvas: .home, sheet: .homeDefault),
                requiresSession: true,
                launchesWithCompletedOnboarding: true,
                marksOnboardingCompleted: true,
                authProvider: .guest,
                googleOutcome: .success,
                appleOutcome: .success,
                homeRoute: nil,
                openSettingsSheet: true,
                startScanningOnAppStart: false,
                family: shared.family,
                selectedMemberId: shared.family.selfMember.id,
                foodNotesAll: shared.foodNotesAll,
                foodNotesSummary: shared.foodNotesSummary,
                permissions: UITestPermissions(cameraAuthorized: true, notificationsAuthorized: true),
                scans: shared.scans,
                stats: shared.stats,
                favorites: shared.favorites,
                chatReplies: chatReplies(),
                tipProducts: tipProducts(),
                tipPurchaseOutcome: .success(message: "Thanks for supporting IngrediCheck"),
                shareMessage: "Share IngrediCheck"
            )
        }
    }

    private static func signInSheetFixture(
        scenario: UITestScenario,
        googleOutcome: UITestAuthOutcome = .success,
        appleOutcome: UITestAuthOutcome = .success
    ) -> UITestFixture {
        UITestFixture(
            scenario: scenario,
            restoredState: (canvas: .heyThere, sheet: .signInToIngrediCheck),
            requiresSession: false,
            launchesWithCompletedOnboarding: false,
            marksOnboardingCompleted: false,
            authProvider: nil,
            googleOutcome: googleOutcome,
            appleOutcome: appleOutcome,
            homeRoute: nil,
            openSettingsSheet: false,
            startScanningOnAppStart: false,
            family: nil,
            selectedMemberId: nil,
            foodNotesAll: nil,
            foodNotesSummary: nil,
            permissions: UITestPermissions(cameraAuthorized: true, notificationsAuthorized: true),
            scans: [],
            stats: emptyStats(),
            favorites: [],
            chatReplies: chatReplies(),
            tipProducts: tipProducts(),
            tipPurchaseOutcome: .success(message: "Thanks for supporting IngrediCheck"),
            shareMessage: "Share IngrediCheck"
        )
    }

    private static func authFixture(
        scenario: UITestScenario,
        shared: inout SharedFixtureData
    ) -> UITestFixture {
        let family = shared.family
        return UITestFixture(
            scenario: scenario,
            restoredState: (canvas: .heyThere, sheet: .signInToIngrediCheck),
            requiresSession: false,
            launchesWithCompletedOnboarding: false,
            marksOnboardingCompleted: true,
            // Do not pre-seed a social provider at launch.
            // The auth flow should remain on the sign-in sheet until the
            // corresponding button is tapped, and the simulated provider
            // is then applied inside signInWithGoogle/signInWithApple.
            authProvider: nil,
            googleOutcome: .success,
            appleOutcome: .success,
            homeRoute: nil,
            openSettingsSheet: false,
            startScanningOnAppStart: false,
            family: family,
            selectedMemberId: family.selfMember.id,
            foodNotesAll: shared.foodNotesAll,
            foodNotesSummary: shared.foodNotesSummary,
            permissions: UITestPermissions(cameraAuthorized: true, notificationsAuthorized: true),
            scans: shared.scans,
            stats: shared.stats,
            favorites: shared.favorites,
            chatReplies: chatReplies(),
            tipProducts: tipProducts(),
            tipPurchaseOutcome: .success(message: "Thanks for supporting IngrediCheck"),
            shareMessage: "Share IngrediCheck"
        )
    }

    private static func homeFixture(
        scenario: UITestScenario,
        homeRoute: AppRoute?,
        openSettingsSheet: Bool,
        family: Family?,
        foodNotesAll: WebService.FoodNotesAllResponse?,
        foodNotesSummary: DTO.FoodNotesSummaryResponse?,
        scans: [DTO.Scan],
        stats: DTO.StatsResponse,
        favorites: [DTO.ListItem],
        tipPurchaseOutcome: UITestTipPurchaseOutcome = .success(message: "Thanks for supporting IngrediCheck"),
        shareMessage: String = "Share us tapped"
    ) -> UITestFixture {
        UITestFixture(
            scenario: scenario,
            restoredState: (canvas: .home, sheet: .homeDefault),
            requiresSession: true,
            launchesWithCompletedOnboarding: true,
            marksOnboardingCompleted: true,
            authProvider: .google,
            googleOutcome: .success,
            appleOutcome: .success,
            homeRoute: homeRoute,
            openSettingsSheet: openSettingsSheet,
            startScanningOnAppStart: false,
            family: family,
            selectedMemberId: family?.selfMember.id,
            foodNotesAll: foodNotesAll,
            foodNotesSummary: foodNotesSummary,
            permissions: UITestPermissions(cameraAuthorized: true, notificationsAuthorized: true),
            scans: scans,
            stats: stats,
            favorites: favorites,
            chatReplies: chatReplies(),
            tipProducts: tipProducts(),
            tipPurchaseOutcome: tipPurchaseOutcome,
            shareMessage: shareMessage
        )
    }

    static func isoDateString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private static func makeFoodNotesSummary() -> DTO.FoodNotesSummaryResponse {
        DTO.FoodNotesSummaryResponse(
            summary: "Avoid peanuts, dairy, and lactose. Prefer lower sugar snacks for the family.",
            generatedAt: isoDateString(),
            isCached: false
        )
    }

    private static func emptyStats() -> DTO.StatsResponse {
        DTO.StatsResponse(
            avgScans: 0,
            barcodeScansCount: 0,
            matchingStats: DTO.MatchingStats(matched: 0, unmatched: 0, uncertain: 0),
            weeklyStats: nil
        )
    }

    private static func makeFamily() -> Family {
        Family(
            name: "Patel Family",
            selfMember: FamilyMember(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "Aarav",
                color: "#BAFFC9",
                joined: true,
                imageFileHash: "memoji_3",
                invitePending: nil
            ),
            otherMembers: [
                FamilyMember(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    name: "Riya",
                    color: "#BAE1FF",
                    joined: true,
                    imageFileHash: "memoji_4",
                    invitePending: nil
                ),
                FamilyMember(
                    id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    name: "Kabir",
                    color: "#FFDFBA",
                    joined: false,
                    imageFileHash: "memoji_5",
                    invitePending: true
                )
            ],
            version: 1
        )
    }

    private static func makeFoodNotesAll(for family: Family?) -> WebService.FoodNotesAllResponse {
        let everyoneContent: [String: Any] = [
            "allergies": [["name": "Peanuts", "iconName": "🥜"]],
            "intolerances": [["name": "Lactose", "iconName": "🥛"]],
            "region": [
                "India & South Asia": [["name": "Ayurveda", "iconName": "🌿"]]
            ],
            "preferences": ["misc": ["Prefer lower sugar snacks"]]
        ]

        let memberContent: [String: Any] = [
            "allergies": [["name": "Dairy", "iconName": "🥛"]],
            "lifeStage": [["name": "Kids Baby-friendly foods", "iconName": "👶"]],
            "preferences": ["misc": ["School lunch safe options only"]]
        ]

        var memberNotes: [String: WebService.FoodNotesResponse] = [:]
        if let family {
            memberNotes[family.selfMember.id.uuidString.lowercased()] = WebService.FoodNotesResponse(
                content: memberContent,
                version: 1,
                updatedAt: isoDateString()
            )
        }

        return WebService.FoodNotesAllResponse(
            familyNote: WebService.FoodNotesResponse(
                content: everyoneContent,
                version: 1,
                updatedAt: isoDateString()
            ),
            memberNotes: memberNotes
        )
    }

    static func makeScans() -> [DTO.Scan] {
        let dietCoke = DTO.Scan(
            id: "scan-diet-coke",
            scan_type: "barcode",
            barcode: "049000028911",
            state: "done",
            product_info: DTO.ScanProductInfo(
                name: "Diet Coke Soft Drink",
                brand: "Coca-Cola",
                ingredients: [
                    DTO.Ingredient(name: "Carbonated Water", vegan: true, vegetarian: true, ingredients: []),
                    DTO.Ingredient(name: "Aspartame", vegan: true, vegetarian: true, ingredients: [])
                ],
                images: [],
                claims: ["Sugar Free"]
            ),
            product_info_source: "ui_test",
            analysis_result: DTO.ScanAnalysisResult(
                id: "analysis-diet-coke",
                overall_analysis: "Looks aligned with your lower sugar preference.",
                overall_match: "matched",
                ingredient_analysis: [],
                is_stale: false,
                vote: nil
            ),
            images: [],
            latest_guidance: "Good lower sugar option.",
            created_at: isoDateString(),
            last_activity_at: isoDateString(),
            error: nil,
            is_favorited: false,
            analysis_id: "analysis-diet-coke"
        )

        let oreo = DTO.Scan(
            id: "scan-oreo",
            scan_type: "barcode",
            barcode: "044000032547",
            state: "done",
            product_info: DTO.ScanProductInfo(
                name: "Oreo Original",
                brand: "Oreo",
                ingredients: [
                    DTO.Ingredient(name: "Sugar", vegan: true, vegetarian: true, ingredients: []),
                    DTO.Ingredient(name: "Wheat Flour", vegan: true, vegetarian: true, ingredients: [])
                ],
                images: [],
                claims: ["Snack"]
            ),
            product_info_source: "ui_test",
            analysis_result: DTO.ScanAnalysisResult(
                id: "analysis-oreo",
                overall_analysis: "Contains wheat and higher sugar.",
                overall_match: "uncertain",
                ingredient_analysis: [
                    DTO.ScanIngredientAnalysis(
                        ingredient: "Wheat Flour",
                        match: "uncertain",
                        reasoning: "Contains wheat which can be problematic for some users.",
                        members_affected: ["everyone"],
                        vote: nil
                    )
                ],
                is_stale: false,
                vote: nil
            ),
            images: [],
            latest_guidance: "Check wheat sensitivity before eating.",
            created_at: isoDateString(),
            last_activity_at: isoDateString(),
            error: nil,
            is_favorited: true,
            analysis_id: "analysis-oreo"
        )

        let photoScan = DTO.Scan(
            id: "scan-photo-veggie",
            scan_type: "photo",
            barcode: nil,
            state: "done",
            product_info: DTO.ScanProductInfo(
                name: "Sea Salt Veggie Chips",
                brand: "Harvest Crunch",
                ingredients: [
                    DTO.Ingredient(name: "Potato", vegan: true, vegetarian: true, ingredients: []),
                    DTO.Ingredient(name: "Sea Salt", vegan: true, vegetarian: true, ingredients: [])
                ],
                images: [],
                claims: ["Gluten Free"]
            ),
            product_info_source: "ui_test",
            analysis_result: DTO.ScanAnalysisResult(
                id: "analysis-photo-veggie",
                overall_analysis: "Photo scan identified a generally safe snack.",
                overall_match: "matched",
                ingredient_analysis: [],
                is_stale: false,
                vote: nil
            ),
            images: [],
            latest_guidance: "Photo scan complete.",
            created_at: isoDateString(),
            last_activity_at: isoDateString(),
            error: nil,
            is_favorited: false,
            analysis_id: "analysis-photo-veggie"
        )

        let invalid = DTO.Scan(
            id: "scan-invalid",
            scan_type: "barcode",
            barcode: "000000000000",
            state: "done",
            product_info: DTO.ScanProductInfo(name: nil, brand: nil, ingredients: [], images: [], claims: nil),
            product_info_source: "ui_test",
            analysis_result: nil,
            images: [],
            latest_guidance: nil,
            created_at: isoDateString(),
            last_activity_at: isoDateString(),
            error: nil,
            is_favorited: false,
            analysis_id: nil
        )

        return [dietCoke, oreo, photoScan, invalid]
    }

    private static func makeFavorites(from scans: [DTO.Scan]) -> [DTO.ListItem] {
        scans
            .filter { $0.is_favorited == true }
            .map {
                DTO.ListItem(
                    created_at: $0.created_at,
                    list_id: "favorites",
                    list_item_id: $0.id,
                    barcode: $0.barcode,
                    brand: $0.product_info.brand,
                    name: $0.product_info.name,
                    ingredients: $0.product_info.ingredients,
                    images: []
                )
            }
    }

    private static func makeStats() -> DTO.StatsResponse {
        DTO.StatsResponse(
            avgScans: 12,
            barcodeScansCount: 34,
            matchingStats: DTO.MatchingStats(matched: 16, unmatched: 4, uncertain: 8),
            weeklyStats: [
                DTO.WeeklyStat(day: "M", value: 2, date: "2026-03-02"),
                DTO.WeeklyStat(day: "T", value: 1, date: "2026-03-03"),
                DTO.WeeklyStat(day: "W", value: 4, date: "2026-03-04"),
                DTO.WeeklyStat(day: "T", value: 2, date: "2026-03-05"),
                DTO.WeeklyStat(day: "F", value: 3, date: "2026-03-06"),
                DTO.WeeklyStat(day: "S", value: 1, date: "2026-03-07"),
                DTO.WeeklyStat(day: "S", value: 2, date: "2026-03-08")
            ]
        )
    }

    private static func chatReplies() -> [String: String] {
        [
            "can i eat this?": "Based on your saved food notes, this looks reasonable but check the wheat content.",
            "what should i avoid?": "Avoid peanuts, dairy, and lactose based on the seeded simulator profile.",
            "hello": "Hello from the simulator QA harness."
        ]
    }

    private static func tipProducts() -> [UITestTipProduct] {
        [
            UITestTipProduct(id: "tip_small", title: "Small Tip", description: "Support IngrediCheck", price: "$1.99"),
            UITestTipProduct(id: "tip_medium", title: "Medium Tip", description: "Keep the scans coming", price: "$4.99"),
            UITestTipProduct(id: "tip_large", title: "Large Tip", description: "Fuel future features", price: "$9.99")
        ]
    }
}

private extension DTO.ScanAnalysisResult {
    init(
        id: String?,
        overall_analysis: String?,
        overall_match: String?,
        ingredient_analysis: [DTO.ScanIngredientAnalysis],
        is_stale: Bool?,
        vote: DTO.Vote?
    ) {
        self.id = id
        self.overall_analysis = overall_analysis
        self.overall_match = overall_match
        self.ingredient_analysis = ingredient_analysis
        self.is_stale = is_stale
        self.vote = vote
    }
}
