import Foundation
import Observation

@Observable @MainActor
final class HomescreenPrefetcher {
    private(set) var didPrefetch = false
    private(set) var prefetchedStats: DTO.StatsResponse?
    private(set) var prefetchedFoodNotesSummary: String?

    private let familyStore: FamilyStore
    private let scanHistoryStore: ScanHistoryStore
    private let webService: WebService

    init(familyStore: FamilyStore, scanHistoryStore: ScanHistoryStore, webService: WebService) {
        self.familyStore = familyStore
        self.scanHistoryStore = scanHistoryStore
        self.webService = webService
    }

    func prefetchIfNeeded() {
        guard !didPrefetch else { return }
        guard OnboardingPersistence.shared.isLocallyCompleted else { return }
        didPrefetch = true

        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in await self.familyStore.loadCurrentFamily() }
                group.addTask { @MainActor in await self.scanHistoryStore.loadHistory(limit: 20, offset: 0) }
                group.addTask { @MainActor in self.prefetchedStats = try? await self.webService.fetchStats() }
                group.addTask { @MainActor in self.prefetchedFoodNotesSummary = try? await self.webService.fetchFoodNotesSummary()?.summary }
                await group.waitForAll()
            }
        }
    }

    func reset() {
        didPrefetch = false
        prefetchedStats = nil
        prefetchedFoodNotesSummary = nil
    }
}
