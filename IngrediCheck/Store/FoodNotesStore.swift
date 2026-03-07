//
//  FoodNotesStore.swift
//  IngrediCheck
//
//  Centralized food notes state with a single-writer actor engine.
//

import SwiftUI
import Observation
import os

@Observable
@MainActor
final class FoodNotesStore {
    typealias OwnerKey = String

    private let webService: WebService
    private let onboardingStore: Onboarding
    private let schema: FoodNotesSchema
    @ObservationIgnored private let bridge: FoodNotesSnapshotBridge
    @ObservationIgnored private let engine: FoodNotesEngine
    @ObservationIgnored private var pendingWriteTask: Task<Void, Never>? = nil
    @ObservationIgnored private var pendingWriteSequence: UInt64 = 0
    @ObservationIgnored private var writeEpoch: UInt64 = 0

    // MARK: - State

    private(set) var activeOwnerKey: OwnerKey = FoodNotesConstants.everyoneKey
    private(set) var currentPreferences: Preferences
    private(set) var ownerPreferences: [OwnerKey: Preferences] = [:]
    var canvasPreferences: Preferences = Preferences()
    var itemMemberAssociations: [String: [String: [String]]] = [:]

    var isLoadingFoodNotes: Bool = false
    private(set) var hasLoadedFoodNotes: Bool = false
    private(set) var memberMiscNotes: [String: [String]] = [:]
    private(set) var isSyncing: Bool = false

    var foodNotesSummary: String? = nil
    private(set) var isLoadingSummary: Bool = false
    private var summaryRefreshTask: Task<Void, Never>? = nil

    var hasNoFoodNotes: Bool {
        if hasLoadedFoodNotes {
            let hasStructuredNotes = !canvasPreferences.sections.isEmpty
            let hasMiscNotes = memberMiscNotes.values.contains { !$0.isEmpty }
            return !(hasStructuredNotes || hasMiscNotes)
        }
        if let summary = foodNotesSummary {
            return FoodNotesStore.isPlaceholderSummary(summary)
        }
        return false
    }

    init(webService: WebService, onboardingStore: Onboarding) {
        self.webService = webService
        self.onboardingStore = onboardingStore
        self.schema = FoodNotesSchema(dynamicSteps: onboardingStore.dynamicSteps)
        self.currentPreferences = onboardingStore.preferences
        self.ownerPreferences = [FoodNotesConstants.everyoneKey: onboardingStore.preferences]

        let bridge = FoodNotesSnapshotBridge()
        self.bridge = bridge
        self.engine = FoodNotesEngine(
            webService: webService,
            schema: self.schema,
            snapshotSink: { [bridge] snapshot in
                await bridge.deliver(snapshot: snapshot)
            },
            summaryRefreshSink: { [bridge] in
                await bridge.refreshSummary()
            }
        )
        bridge.attach(to: self)
    }

    // MARK: - Summary

    static func isPlaceholderSummary(_ summary: String) -> Bool {
        let lower = summary.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lower.isEmpty || lower.contains("no food notes") || lower.contains("no data yet")
    }

    func refreshSummary() {
        summaryRefreshTask?.cancel()
        summaryRefreshTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await loadFoodNotesSummaryInternal()
        }
    }

    func loadSummaryIfNeeded() async {
        if foodNotesSummary == nil {
            await loadFoodNotesSummaryInternal()
        }
    }

    private func loadFoodNotesSummaryInternal() async {
        guard !isLoadingSummary else { return }
        isLoadingSummary = true
        defer { isLoadingSummary = false }

        Log.debug("FoodNotesStore", "Loading food notes summary...")
        do {
            let response = try await webService.fetchFoodNotesSummary()
            foodNotesSummary = response?.summary
            Log.debug("FoodNotesStore", "Summary loaded: \(foodNotesSummary ?? "nil")")
        } catch {
            Log.error("FoodNotesStore", "Failed to load summary: \(error)")
        }
    }

    // MARK: - Bootstrap / Refresh

    func bootstrap(family: Family?, selectedMemberId: UUID?) async {
        let ownerKey = resolveBootstrapOwnerKey(selectedMemberId: selectedMemberId, family: family)
        projectActiveOwnerLocally(ownerKey)
        await engine.setActiveOwner(ownerKey)
        await refreshFromServer(family: family)
    }

    func loadFoodNotesAll() async {
        await refreshFromServer(family: nil)
    }

    func refreshFromServer(family: Family?) async {
        guard !isLoadingFoodNotes else { return }
        isLoadingFoodNotes = true
        defer { isLoadingFoodNotes = false }
        await engine.refreshFromServer(family: family)
    }

    func setActiveMember(_ selectedMemberId: UUID?) async {
        let ownerKey = Self.ownerKey(for: selectedMemberId)
        projectActiveOwnerLocally(ownerKey)
        await engine.setActiveOwner(ownerKey)
    }

    // MARK: - Explicit Preference Writes

    func replacePreferences(_ preferences: Preferences, ownerKey: OwnerKey) async {
        await engine.replacePreferences(ownerKey: ownerKey, preferences: preferences, sessionEpoch: writeEpoch)
    }

    func binding(for step: DynamicStep, ownerKey: OwnerKey) -> Binding<PreferenceValue?> {
        let sectionName = step.header.name

        return Binding(
            get: { self.preferences(for: ownerKey).sections[sectionName] },
            set: { newValue in
                self.updateSectionValue(newValue, sectionName: sectionName, ownerKey: ownerKey)
            }
        )
    }

    func updateSectionValue(_ value: PreferenceValue?, sectionName: String, ownerKey: OwnerKey) {
        let normalizedValue = FoodNotesNormalizer.normalizeSectionValue(value)
        let existingPreferences = preferences(for: ownerKey)
        var nextPreferences = existingPreferences

        if let normalizedValue {
            nextPreferences.sections[sectionName] = normalizedValue
        } else {
            nextPreferences.sections.removeValue(forKey: sectionName)
        }

        guard nextPreferences != existingPreferences else { return }

        ownerPreferences[ownerKey] = nextPreferences
        if ownerKey == activeOwnerKey {
            currentPreferences = nextPreferences
        }
        if ownerKey == activeOwnerKey, onboardingStore.preferences != nextPreferences {
            onboardingStore.preferences = nextPreferences
        }
        if ownerKey == activeOwnerKey {
            onboardingStore.updateSectionCompletionStatus()
        }

        queuePreferencesWrite(nextPreferences, ownerKey: ownerKey)
    }

    func flushPendingSyncs(ownerKey: OwnerKey? = nil) async {
        while true {
            let sequence = pendingWriteSequence
            if let pendingWriteTask {
                _ = await pendingWriteTask.result
            }
            guard sequence != pendingWriteSequence else { break }
        }
        await engine.flushNow(ownerKey: ownerKey)
    }

    func clearOwnerState(for memberId: UUID) async {
        await engine.clearOwnerState(ownerKey: Self.ownerKey(for: memberId))
    }

    func resetLocalState() async {
        summaryRefreshTask?.cancel()
        summaryRefreshTask = nil
        writeEpoch &+= 1
        pendingWriteTask?.cancel()
        pendingWriteTask = nil
        foodNotesSummary = nil
        ownerPreferences = [:]
        await engine.reset()
    }

    // MARK: - Helpers

    func resolveEditingMemberId(selectedMemberId: UUID?, family: Family?) -> UUID? {
        guard selectedMemberId == nil,
              let family,
              family.otherMembers.isEmpty else {
            return selectedMemberId
        }
        return family.selfMember.id
    }

    func resolveEditingOwnerKey(selectedMemberId: UUID?, family: Family?) -> OwnerKey {
        Self.ownerKey(for: resolveEditingMemberId(selectedMemberId: selectedMemberId, family: family))
    }

    func resolveOnboardingOwnerKey(
        selectedMemberId: UUID?,
        family: Family?,
        flowType: OnboardingFlowType
    ) -> OwnerKey {
        switch flowType {
        case .individual:
            return FoodNotesConstants.everyoneKey
        case .family:
            return Self.ownerKey(for: selectedMemberId)
        case .singleMember:
            return resolveEditingOwnerKey(selectedMemberId: selectedMemberId, family: family)
        }
    }

    private func resolveBootstrapOwnerKey(selectedMemberId: UUID?, family: Family?) -> OwnerKey {
        if let family, family.otherMembers.isEmpty {
            return resolveEditingOwnerKey(selectedMemberId: selectedMemberId, family: family)
        }

        return Self.ownerKey(for: selectedMemberId)
    }

    fileprivate func apply(_ snapshot: FoodNotesSnapshot) {
        activeOwnerKey = snapshot.activeOwnerKey
        ownerPreferences = snapshot.ownerPreferences
        currentPreferences = snapshot.currentPreferences
        canvasPreferences = snapshot.canvasPreferences
        itemMemberAssociations = snapshot.itemMemberAssociations
        hasLoadedFoodNotes = snapshot.hasLoadedFoodNotes
        memberMiscNotes = snapshot.memberMiscNotes
        isSyncing = snapshot.isSyncing

        if onboardingStore.preferences != snapshot.currentPreferences {
            onboardingStore.preferences = snapshot.currentPreferences
        }
        onboardingStore.updateSectionCompletionStatus()
    }

    static func ownerKey(for selectedMemberId: UUID?) -> OwnerKey {
        selectedMemberId?.uuidString.lowercased() ?? FoodNotesConstants.everyoneKey
    }

    static func ownerKey(for memberId: UUID) -> OwnerKey {
        memberId.uuidString.lowercased()
    }

    private func queuePreferencesWrite(_ preferences: Preferences, ownerKey: OwnerKey) {
        let previousTask = pendingWriteTask
        let engine = self.engine
        let writeEpoch = self.writeEpoch
        pendingWriteSequence &+= 1

        pendingWriteTask = Task { @MainActor in
            _ = await previousTask?.result
            guard !Task.isCancelled, self.writeEpoch == writeEpoch else { return }
            await engine.replacePreferences(ownerKey: ownerKey, preferences: preferences, sessionEpoch: writeEpoch)
        }
    }

    private func preferences(for ownerKey: OwnerKey) -> Preferences {
        ownerPreferences[ownerKey] ?? Preferences()
    }

    private func projectActiveOwnerLocally(_ ownerKey: OwnerKey) {
        activeOwnerKey = ownerKey
        currentPreferences = preferences(for: ownerKey)

        if onboardingStore.preferences != currentPreferences {
            onboardingStore.preferences = currentPreferences
        }
        onboardingStore.updateSectionCompletionStatus()
    }
}

// MARK: - Engine

private actor FoodNotesEngine {
    typealias OwnerKey = FoodNotesStore.OwnerKey

    private let webService: WebService
    private let schema: FoodNotesSchema
    private let snapshotSink: @Sendable (FoodNotesSnapshot) async -> Void
    private let summaryRefreshSink: @Sendable () async -> Void

    private var owners: [OwnerKey: FoodNotesOwnerState] = [:]
    private var activeOwnerKey: OwnerKey = FoodNotesConstants.everyoneKey
    private var hasLoadedFoodNotes = false
    private var scheduledSyncTokens: [OwnerKey: UInt64] = [:]
    private var nextSyncToken: UInt64 = 0
    private var sessionEpoch: UInt64 = 0

    init(
        webService: WebService,
        schema: FoodNotesSchema,
        snapshotSink: @escaping @Sendable (FoodNotesSnapshot) async -> Void,
        summaryRefreshSink: @escaping @Sendable () async -> Void
    ) {
        self.webService = webService
        self.schema = schema
        self.snapshotSink = snapshotSink
        self.summaryRefreshSink = summaryRefreshSink
    }

    func setActiveOwner(_ ownerKey: OwnerKey) async {
        ensureOwnerExists(ownerKey)
        activeOwnerKey = ownerKey
        await emitSnapshot()
    }

    func refreshFromServer(family: Family?) async {
        let refreshSessionEpoch = sessionEpoch
        do {
            let response = try await webService.fetchFoodNotesAll()
            guard sessionEpoch == refreshSessionEpoch else { return }
            rebuildOwners(from: response)
            migrateSingleMemberEveryoneDataIfNeeded(family: family)
            hasLoadedFoodNotes = true
            await emitSnapshot()
        } catch {
            guard sessionEpoch == refreshSessionEpoch else { return }
            Log.error("FoodNotesEngine", "refreshFromServer failed: \(error)")
            if owners.isEmpty {
                ensureOwnerExists(FoodNotesConstants.everyoneKey)
                hasLoadedFoodNotes = true
            }
            await emitSnapshot()
        }
    }

    func replacePreferences(ownerKey: OwnerKey, preferences: Preferences, sessionEpoch: UInt64) async {
        guard sessionEpoch == self.sessionEpoch else { return }
        ensureOwnerExists(ownerKey)
        var owner = owners[ownerKey] ?? FoodNotesOwnerState(resetEpoch: sessionEpoch)
        let normalized = FoodNotesNormalizer.normalize(preferences)
        owner.pendingReplacement = FoodNotesPendingReplacement(id: UUID(), preferences: normalized)
        owner.working = normalized
        owners[ownerKey] = owner
        await emitSnapshot()
        scheduleSync(for: ownerKey)
    }

    func flushNow(ownerKey: OwnerKey?) async {
        if let ownerKey {
            await performSync(ownerKey: ownerKey, retryCount: 0)
            return
        }

        let keys = Array(owners.keys).sorted()
        for key in keys {
            await performSync(ownerKey: key, retryCount: 0)
        }
    }

    func clearOwnerState(ownerKey: OwnerKey) async {
        ensureOwnerExists(ownerKey)
        var owner = owners[ownerKey] ?? FoodNotesOwnerState(resetEpoch: sessionEpoch)
        owner.base = Preferences()
        owner.working = Preferences()
        owner.pendingReplacement = nil
        owner.version = 0
        owner.miscNotes = []
        owner.requiresSync = false
        owner.isSyncing = false
        owner.resetEpoch &+= 1
        owners[ownerKey] = owner
        scheduledSyncTokens[ownerKey] = nil
        await emitSnapshot()
    }

    func reset() async {
        sessionEpoch &+= 1
        owners = [:]
        activeOwnerKey = FoodNotesConstants.everyoneKey
        hasLoadedFoodNotes = false
        scheduledSyncTokens = [:]
        ensureOwnerExists(activeOwnerKey)
        await emitSnapshot()
    }

    // MARK: - Refresh Merge

    private func rebuildOwners(from response: WebService.FoodNotesAllResponse?) {
        let serverNotes = parseServerNotes(response)
        let allKeys = Set(owners.keys).union(serverNotes.keys).union([FoodNotesConstants.everyoneKey, activeOwnerKey])

        var rebuilt: [OwnerKey: FoodNotesOwnerState] = [:]
        for key in allKeys {
            let previous = owners[key] ?? FoodNotesOwnerState(resetEpoch: sessionEpoch)
            let server = serverNotes[key]

            var next = previous
            next.base = server?.preferences ?? Preferences()
            next.version = server?.version ?? 0
            next.miscNotes = resolvedMiscNotes(previous: previous, server: server)
            next.working = previous.pendingReplacement?.preferences ?? next.base
            rebuilt[key] = next
        }

        owners = rebuilt
        ensureOwnerExists(activeOwnerKey)
    }

    private func parseServerNotes(_ response: WebService.FoodNotesAllResponse?) -> [OwnerKey: FoodNotesServerNote] {
        guard let response else {
            return [:]
        }

        var notes: [OwnerKey: FoodNotesServerNote] = [:]

        if let familyNote = response.familyNote {
            notes[FoodNotesConstants.everyoneKey] = FoodNotesServerNote(
                preferences: convertContentToPreferences(content: familyNote.content),
                version: familyNote.version,
                miscNotes: extractMiscNotes(from: familyNote.content)
            )
        }

        for (memberId, note) in response.memberNotes {
            notes[memberId.lowercased()] = FoodNotesServerNote(
                preferences: convertContentToPreferences(content: note.content),
                version: note.version,
                miscNotes: extractMiscNotes(from: note.content)
            )
        }

        return notes
    }

    // MARK: - Migration

    private func migrateSingleMemberEveryoneDataIfNeeded(family: Family?) {
        guard let family, family.otherMembers.isEmpty else { return }

        let selfKey = family.selfMember.id.uuidString.lowercased()
        ensureOwnerExists(selfKey)
        ensureOwnerExists(FoodNotesConstants.everyoneKey)

        let everyone = owners[FoodNotesConstants.everyoneKey] ?? FoodNotesOwnerState(resetEpoch: sessionEpoch)
        let selfOwner = owners[selfKey] ?? FoodNotesOwnerState(resetEpoch: sessionEpoch)

        let everyoneHasStructuredData = FoodNotesNormalizer.hasAnySelections(in: everyone.working)
        let everyoneHasMiscNotes = !everyone.miscNotes.isEmpty
        guard everyoneHasStructuredData || everyoneHasMiscNotes else { return }

        let mergedPreferences = mergePreferences(base: selfOwner.working, with: everyone.working)
        let mergedMiscNotes = mergeUniqueStrings(base: selfOwner.miscNotes, with: everyone.miscNotes)

        var updatedSelf = selfOwner
        if mergedPreferences != selfOwner.working {
            updatedSelf.pendingReplacement = FoodNotesPendingReplacement(id: UUID(), preferences: mergedPreferences)
            updatedSelf.working = mergedPreferences
        }
        if mergedMiscNotes != selfOwner.miscNotes {
            updatedSelf.miscNotes = mergedMiscNotes
            updatedSelf.requiresSync = true
        }
        owners[selfKey] = updatedSelf

        var updatedEveryone = everyone
        updatedEveryone.pendingReplacement = FoodNotesPendingReplacement(id: UUID(), preferences: Preferences())
        updatedEveryone.working = Preferences()
        if !updatedEveryone.miscNotes.isEmpty {
            updatedEveryone.miscNotes = []
            updatedEveryone.requiresSync = true
        }
        owners[FoodNotesConstants.everyoneKey] = updatedEveryone

        scheduleSync(for: selfKey, delayMs: 100)
        scheduleSync(for: FoodNotesConstants.everyoneKey, delayMs: 100)
    }

    // MARK: - Sync

    private func scheduleSync(for ownerKey: OwnerKey, delayMs: UInt64 = 1_500) {
        nextSyncToken &+= 1
        let token = nextSyncToken
        scheduledSyncTokens[ownerKey] = token

        Task {
            try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            await self.flushIfScheduled(ownerKey: ownerKey, token: token)
        }
    }

    private func flushIfScheduled(ownerKey: OwnerKey, token: UInt64) async {
        guard scheduledSyncTokens[ownerKey] == token else { return }
        await performSync(ownerKey: ownerKey, retryCount: 0)
    }

    private func performSync(ownerKey: OwnerKey, retryCount: Int) async {
        guard var owner = owners[ownerKey] else { return }
        guard (owner.pendingReplacement != nil || owner.requiresSync) && !owner.isSyncing else { return }

        owner.isSyncing = true
        let syncSessionEpoch = sessionEpoch
        let syncEpoch = owner.resetEpoch
        let syncedReplacementID = owner.pendingReplacement?.id
        let syncVersion = owner.version
        let syncPreferences = owner.working
        let syncMiscNotes = owner.miscNotes
        owners[ownerKey] = owner
        await emitSnapshot()

        do {
            var content = buildContentFromPreferences(preferences: syncPreferences)
            if !syncMiscNotes.isEmpty {
                var preferencesDict = content["preferences"] as? [String: Any] ?? [:]
                preferencesDict["misc"] = syncMiscNotes
                content["preferences"] = preferencesDict
            }

            let response: WebService.FoodNotesResponse
            if ownerKey == FoodNotesConstants.everyoneKey {
                response = try await webService.updateFoodNotes(content: content, version: syncVersion)
            } else {
                response = try await webService.updateMemberFoodNotes(
                    memberId: ownerKey,
                    content: content,
                    version: syncVersion
                )
            }

            guard sessionEpoch == syncSessionEpoch,
                  var current = owners[ownerKey],
                  current.resetEpoch == syncEpoch else { return }

            current.isSyncing = false
            current.base = convertContentToPreferences(content: response.content)
            current.version = response.version
            current.miscNotes = extractMiscNotes(from: response.content)
            current.requiresSync = false
            if current.pendingReplacement?.id == syncedReplacementID {
                current.pendingReplacement = nil
            }
            current.working = current.pendingReplacement?.preferences ?? current.base
            owners[ownerKey] = current
            scheduledSyncTokens[ownerKey] = nil

            await emitSnapshot()
            await summaryRefreshSink()

            if current.pendingReplacement != nil || current.requiresSync {
                scheduleSync(for: ownerKey, delayMs: 100)
            }
        } catch let error as WebService.VersionMismatchError {
            guard sessionEpoch == syncSessionEpoch,
                  var current = owners[ownerKey],
                  current.resetEpoch == syncEpoch else { return }

            current.isSyncing = false
            current.base = convertContentToPreferences(content: error.currentNote.content)
            current.version = error.currentNote.version
            current.miscNotes = extractMiscNotes(from: error.currentNote.content)
            current.working = current.pendingReplacement?.preferences ?? current.base
            owners[ownerKey] = current

            await emitSnapshot()

            if retryCount < 3 {
                await performSync(ownerKey: ownerKey, retryCount: retryCount + 1)
            } else {
                scheduleSync(for: ownerKey, delayMs: 2_000)
            }
        } catch {
            guard sessionEpoch == syncSessionEpoch,
                  var current = owners[ownerKey],
                  current.resetEpoch == syncEpoch else { return }

            current.isSyncing = false
            owners[ownerKey] = current
            await emitSnapshot()
            scheduleSync(for: ownerKey, delayMs: 2_000)
        }
    }

    // MARK: - Snapshot

    private func emitSnapshot() async {
        await snapshotSink(buildSnapshot())
    }

    private func buildSnapshot() -> FoodNotesSnapshot {
        let projection = buildProjection()
        let currentPreferences = owners[activeOwnerKey]?.working ?? Preferences()

        return FoodNotesSnapshot(
            activeOwnerKey: activeOwnerKey,
            currentPreferences: currentPreferences,
            ownerPreferences: owners.mapValues { $0.working },
            canvasPreferences: projection.canvasPreferences,
            itemMemberAssociations: projection.itemMemberAssociations,
            memberMiscNotes: owners.mapValues { $0.miscNotes },
            hasLoadedFoodNotes: hasLoadedFoodNotes,
            isSyncing: owners.values.contains { $0.isSyncing }
        )
    }

    private func buildProjection() -> FoodNotesProjection {
        var associations: [String: [String: [String]]] = [:]
        var canvas = Preferences()

        for (ownerKey, owner) in owners {
            let prefs = owner.working

            for (sectionName, value) in prefs.sections {
                switch value {
                case .list(let items):
                    let cleanedItems = FoodNotesNormalizer.uniqueStrings(items)
                    if !cleanedItems.isEmpty {
                        if case .list(let existingItems) = canvas.sections[sectionName] {
                            canvas.sections[sectionName] = .list(
                                FoodNotesNormalizer.uniqueStrings(existingItems + cleanedItems)
                            )
                        } else {
                            canvas.sections[sectionName] = .list(cleanedItems)
                        }
                    }

                    for item in cleanedItems {
                        associations[sectionName, default: [:]][item, default: []].append(ownerKey)
                    }

                case .nested(let nestedDict):
                    var canvasNested: [String: [String]]
                    if case .nested(let existingNested) = canvas.sections[sectionName] {
                        canvasNested = existingNested
                    } else {
                        canvasNested = [:]
                    }

                    for (nestedKey, items) in nestedDict {
                        let cleanedItems = FoodNotesNormalizer.uniqueStrings(items)
                        guard !cleanedItems.isEmpty else { continue }

                        canvasNested[nestedKey] = FoodNotesNormalizer.uniqueStrings(
                            (canvasNested[nestedKey] ?? []) + cleanedItems
                        )

                        for item in cleanedItems {
                            associations[sectionName, default: [:]][item, default: []].append(ownerKey)
                        }
                    }

                    let cleanedNested = canvasNested.compactMapValues { value in
                        value.isEmpty ? nil : value
                    }
                    if !cleanedNested.isEmpty {
                        canvas.sections[sectionName] = .nested(cleanedNested)
                    }
                }
            }
        }

        for sectionName in Array(associations.keys) {
            guard var sectionAssociations = associations[sectionName] else { continue }
            for item in Array(sectionAssociations.keys) {
                sectionAssociations[item] = FoodNotesNormalizer.uniqueStrings(
                    sectionAssociations[item] ?? []
                )
            }
            associations[sectionName] = sectionAssociations
        }

        return FoodNotesProjection(
            canvasPreferences: FoodNotesNormalizer.normalize(canvas),
            itemMemberAssociations: associations
        )
    }

    // MARK: - Conversion

    private func convertContentToPreferences(content: [String: Any]) -> Preferences {
        var preferences = Preferences()

        for (stepId, stepContent) in content {
            guard let step = schema.step(for: stepId) else { continue }

            if let itemsArray = stepContent as? [[String: Any]] {
                let itemNames = itemsArray.compactMap { $0["name"] as? String }
                if !itemNames.isEmpty {
                    preferences.sections[step.sectionName] = .list(FoodNotesNormalizer.uniqueStrings(itemNames))
                }
            } else if let nestedDict = stepContent as? [String: Any] {
                var prefNested: [String: [String]] = [:]
                for (key, val) in nestedDict {
                    if let arr = val as? [[String: Any]] {
                        let names = arr.compactMap { $0["name"] as? String }
                        if !names.isEmpty {
                            prefNested[key] = FoodNotesNormalizer.uniqueStrings(names)
                        }
                    }
                }
                if !prefNested.isEmpty {
                    preferences.sections[step.sectionName] = .nested(prefNested)
                }
            }
        }

        return FoodNotesNormalizer.normalize(preferences)
    }

    private func buildContentFromPreferences(preferences: Preferences) -> [String: Any] {
        var content: [String: Any] = [:]

        for step in schema.steps {
            guard let value = preferences.sections[step.sectionName] else {
                content[step.stepId] = step.isList ? [[String: Any]]() : [String: Any]()
                continue
            }

            switch value {
            case .list(let items):
                let normalizedItems = FoodNotesNormalizer.uniqueStrings(items)
                let array = normalizedItems.map { itemName in
                    [
                        "name": itemName,
                        "iconName": step.optionIcons[itemName] ?? ""
                    ]
                }
                content[step.stepId] = array

            case .nested(let nested):
                var nestedContent: [String: Any] = [:]
                for (key, items) in nested {
                    nestedContent[key] = FoodNotesNormalizer.uniqueStrings(items).map { itemName in
                        [
                            "name": itemName,
                            "iconName": ""
                        ]
                    }
                }
                content[step.stepId] = nestedContent
            }
        }

        return content
    }

    private func extractMiscNotes(from content: [String: Any]) -> [String] {
        guard let preferences = content["preferences"] as? [String: Any],
              let misc = preferences["misc"] as? [String] else {
            return []
        }
        return FoodNotesNormalizer.uniqueStrings(misc)
    }

    // MARK: - Internal Helpers

    private func ensureOwnerExists(_ ownerKey: OwnerKey) {
        if owners[ownerKey] == nil {
            owners[ownerKey] = FoodNotesOwnerState(resetEpoch: sessionEpoch)
        }
    }

    private func resolvedMiscNotes(
        previous: FoodNotesOwnerState,
        server: FoodNotesServerNote?
    ) -> [String] {
        if previous.requiresSync {
            return previous.miscNotes
        }
        return server?.miscNotes ?? []
    }

    private func mergePreferences(base: Preferences, with incoming: Preferences) -> Preferences {
        var merged = base

        for (sectionName, incomingValue) in incoming.sections {
            guard let existingValue = merged.sections[sectionName] else {
                merged.sections[sectionName] = incomingValue
                continue
            }

            switch (existingValue, incomingValue) {
            case (.list(let existingItems), .list(let incomingItems)):
                merged.sections[sectionName] = .list(
                    FoodNotesNormalizer.uniqueStrings(existingItems + incomingItems)
                )

            case (.nested(let existingNested), .nested(let incomingNested)):
                var combined = existingNested
                for (nestedKey, incomingItems) in incomingNested {
                    combined[nestedKey] = FoodNotesNormalizer.uniqueStrings(
                        (combined[nestedKey] ?? []) + incomingItems
                    )
                }
                merged.sections[sectionName] = .nested(combined)

            default:
                continue
            }
        }

        return FoodNotesNormalizer.normalize(merged)
    }

    private func mergeUniqueStrings(base: [String], with incoming: [String]) -> [String] {
        FoodNotesNormalizer.uniqueStrings(base + incoming)
    }
}

// MARK: - Supporting Types

private enum FoodNotesConstants {
    static let everyoneKey = "Everyone"
}

private final class FoodNotesSnapshotBridge: @unchecked Sendable {
    private weak var store: FoodNotesStore?

    @MainActor
    func attach(to store: FoodNotesStore) {
        self.store = store
    }

    func deliver(snapshot: FoodNotesSnapshot) async {
        await MainActor.run { [weak self] in
            self?.store?.apply(snapshot)
        }
    }

    func refreshSummary() async {
        await MainActor.run { [weak self] in
            self?.store?.refreshSummary()
        }
    }
}

private struct FoodNotesSchema: Sendable {
    let steps: [FoodNotesSchemaStep]
    private let stepsByID: [String: FoodNotesSchemaStep]

    init(dynamicSteps: [DynamicStep]) {
        let mapped = dynamicSteps.map { step in
            FoodNotesSchemaStep(
                stepId: step.id,
                sectionName: step.header.name,
                isList: step.type == .type1,
                optionIcons: Dictionary(
                    uniqueKeysWithValues: (step.content.options ?? []).map { ($0.name, $0.icon) }
                )
            )
        }
        self.steps = mapped
        self.stepsByID = Dictionary(uniqueKeysWithValues: mapped.map { ($0.stepId, $0) })
    }

    func step(for stepId: String) -> FoodNotesSchemaStep? {
        stepsByID[stepId]
    }
}

private struct FoodNotesSchemaStep: Sendable {
    let stepId: String
    let sectionName: String
    let isList: Bool
    let optionIcons: [String: String]
}

private struct FoodNotesSnapshot: Sendable {
    let activeOwnerKey: String
    let currentPreferences: Preferences
    let ownerPreferences: [String: Preferences]
    let canvasPreferences: Preferences
    let itemMemberAssociations: [String: [String: [String]]]
    let memberMiscNotes: [String: [String]]
    let hasLoadedFoodNotes: Bool
    let isSyncing: Bool
}

private struct FoodNotesProjection: Sendable {
    let canvasPreferences: Preferences
    let itemMemberAssociations: [String: [String: [String]]]
}

private struct FoodNotesServerNote: Sendable {
    let preferences: Preferences
    let version: Int
    let miscNotes: [String]
}

private struct FoodNotesPendingReplacement: Sendable {
    let id: UUID
    let preferences: Preferences
}

private struct FoodNotesOwnerState {
    var base: Preferences = Preferences()
    var working: Preferences = Preferences()
    var pendingReplacement: FoodNotesPendingReplacement? = nil
    var version: Int = 0
    var miscNotes: [String] = []
    var requiresSync: Bool = false
    var isSyncing: Bool = false
    var resetEpoch: UInt64 = 0
}

private enum FoodNotesNormalizer {
    static func normalizeSectionValue(_ value: PreferenceValue?) -> PreferenceValue? {
        guard let value else { return nil }

        switch value {
        case .list(let items):
            let cleaned = uniqueStrings(items)
            return cleaned.isEmpty ? nil : .list(cleaned)

        case .nested(let nested):
            let cleanedNested = nested.compactMapValues { items -> [String]? in
                let cleaned = uniqueStrings(items)
                return cleaned.isEmpty ? nil : cleaned
            }
            return cleanedNested.isEmpty ? nil : .nested(cleanedNested)
        }
    }

    static func normalize(_ preferences: Preferences) -> Preferences {
        var normalizedSections: [String: PreferenceValue] = [:]

        for (sectionName, value) in preferences.sections {
            if let normalizedValue = normalizeSectionValue(value) {
                normalizedSections[sectionName] = normalizedValue
            }
        }

        return Preferences(sections: normalizedSections)
    }

    static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values where seen.insert(value).inserted {
            result.append(value)
        }

        return result
    }

    static func hasAnySelections(in preferences: Preferences) -> Bool {
        for value in preferences.sections.values {
            switch value {
            case .list(let items):
                if !items.isEmpty { return true }
            case .nested(let nested):
                if nested.values.contains(where: { !$0.isEmpty }) { return true }
            }
        }
        return false
    }
}
