//
//  FoodNotesStore.swift
//  IngrediCheck
//
//  Created to centralize food notes/chip selection logic for reuse across the app.
//

import SwiftUI
import Observation
import os

@Observable
@MainActor
final class FoodNotesStore {
    private let webService: WebService
    private let onboardingStore: Onboarding
    
    // MARK: - State
    
    /// Current version for family-level optimistic updates
    private var familyVersion: Int = 0
    
    /// Current versions for member-specific optimistic updates, keyed by memberId (UUID string)
    private var memberVersions: [String: Int] = [:]
    
    /// Tracks which entity currently owns the `onboardingStore.preferences`.
    /// "Everyone" for family-level, or a member UUID string for member-level.
    private var currentPreferencesOwnerKey: String? = nil
    
    /// Master cache of preferences for each member.
    /// This is the source of truth for switching users.
    /// Key: Member UUID string or "Everyone"
    private var memberPreferencesCache: [String: Preferences] = [:]
    
    /// Union view preferences used for canvas/background cards (Everyone + all members)
    /// This does not change when switching members in the edit sheet.
    var canvasPreferences: Preferences = Preferences()
    
    /// Tracks which members have which items: [sectionName: [itemName: [memberIds]]]
    /// Member IDs are UUID strings or "Everyone" for family-level items.
    var itemMemberAssociations: [String: [String: [String]]] = [:]
    
    /// Loading state for food notes operations
    var isLoadingFoodNotes: Bool = false

    /// Indicates if food notes have been loaded at least once (prevents showing loading on subsequent navigations)
    private(set) var hasLoadedFoodNotes: Bool = false

    /// Misc notes set by IngrediBot, keyed by member UUID or "Everyone"
    private(set) var memberMiscNotes: [String: [String]] = [:]

    /// Sync management - exposed for UI to show sync indicator
    private(set) var isSyncing: Bool = false
    private var syncDebounceTask: Task<Void, Never>? = nil
    private var pendingSyncMembers: Set<String> = []

    // MARK: - Summary State

    /// Cached summary of food notes from API
    var foodNotesSummary: String? = nil

    /// Loading state for summary
    private(set) var isLoadingSummary: Bool = false

    /// Debounce task for summary refresh
    private var summaryRefreshTask: Task<Void, Never>? = nil
    
    init(webService: WebService, onboardingStore: Onboarding) {
        self.webService = webService
        self.onboardingStore = onboardingStore
    }

    // MARK: - Summary

    /// Public method to refresh summary - debounced to avoid rapid-fire calls
    func refreshSummary() {
        summaryRefreshTask?.cancel()
        summaryRefreshTask = Task {
            try? await Task.sleep(for: .milliseconds(500))  // Debounce
            guard !Task.isCancelled else { return }
            await loadFoodNotesSummaryInternal()
        }
    }

    /// Loads summary directly without debounce. Use from coordinated initial loads (e.g. HomeView).
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

    // MARK: - Loading Food Notes
    
    /// Loads the union view (family + all members) from GET /ingredicheck/family/food-notes/all.
    func loadFoodNotesAll() async {
        Log.debug("FoodNotesStore", "loadFoodNotesAll: Starting to load food notes from backend")
        
        isLoadingFoodNotes = true
        defer { isLoadingFoodNotes = false }
        
        do {
            if let response = try await webService.fetchFoodNotesAll() {
                Log.debug("FoodNotesStore", "loadFoodNotesAll: ✅ Received food notes data")
                
                // 1. Parse Family Note ("Everyone")
                if let familyNote = response.familyNote {
                    familyVersion = familyNote.version
                    let prefs = convertContentToPreferences(content: familyNote.content, dynamicSteps: onboardingStore.dynamicSteps)
                    memberPreferencesCache["Everyone"] = prefs
                    memberMiscNotes["Everyone"] = extractMiscNotes(from: familyNote.content)
                } else {
                    memberPreferencesCache["Everyone"] = Preferences()
                    memberMiscNotes["Everyone"] = []
                }

                // 2. Parse Member Notes
                for (memberId, memberNote) in response.memberNotes {
                    let normalizedId = memberId.lowercased()
                    memberVersions[normalizedId] = memberNote.version
                    let prefs = convertContentToPreferences(content: memberNote.content, dynamicSteps: onboardingStore.dynamicSteps)
                    memberPreferencesCache[normalizedId] = prefs
                    memberMiscNotes[normalizedId] = extractMiscNotes(from: memberNote.content)
                }
                
                // 3. Rebuild Associations and Canvas from the cache
                rebuildAssociationsAndCanvasFromCache()
                
                Log.debug("FoodNotesStore", "loadFoodNotesAll: ✅ Successfully loaded and cached data")
                hasLoadedFoodNotes = true
            } else {
                // No data, init empty
                familyVersion = 0
                memberVersions = [:]
                memberPreferencesCache = [:]
                memberMiscNotes = [:]
                itemMemberAssociations = [:]
                canvasPreferences = Preferences()
                hasLoadedFoodNotes = true
            }
        } catch {
            Log.debug("FoodNotesStore", "loadFoodNotesAll: ❌ Failed to load food notes: \(error.localizedDescription)")
            // Init empty on error to prevent crash
            memberPreferencesCache = [:]
            memberMiscNotes = [:]
            itemMemberAssociations = [:]
            canvasPreferences = Preferences()
        }
    }
    
    // MARK: - Member Switching

    /// Clears the current preferences owner key without saving.
    /// Call before Onboarding.reset() to prevent stale state from corrupting the cache.
    func clearCurrentPreferencesOwner() {
        currentPreferencesOwnerKey = nil
    }

    /// Clears cached preferences for a specific member so they start with a clean slate.
    func clearMemberCache(for memberId: UUID) {
        memberPreferencesCache[memberId.uuidString.lowercased()] = nil
    }

    /// Switches the active preferences to the specified member.
    /// Saves the current member's state to cache before switching.
    func preparePreferencesForMember(selectedMemberId: UUID?) {
        let newMemberKey = selectedMemberId?.uuidString.lowercased() ?? "Everyone"
        
        // 1. Save current preferences to cache for the OLD member
        if let currentKey = currentPreferencesOwnerKey {
            Log.debug("FoodNotesStore", "preparePreferencesForMember: Caching preferences for \(currentKey)")
            memberPreferencesCache[currentKey] = onboardingStore.preferences
        }
        
        // 2. Load preferences from cache for the NEW member
        Log.debug("FoodNotesStore", "preparePreferencesForMember: Switching to \(newMemberKey)")
        if let cachedPrefs = memberPreferencesCache[newMemberKey] {
            onboardingStore.preferences = cachedPrefs
        } else {
            // If not in cache (e.g. new member), start empty
            onboardingStore.preferences = Preferences()
            memberPreferencesCache[newMemberKey] = Preferences()
        }
        
        onboardingStore.updateSectionCompletionStatus()
        currentPreferencesOwnerKey = newMemberKey
    }
    
    // MARK: - Updates & Sync
    
    /// Called when the user makes a change in the UI.
    /// Updates local cache, associations, canvas, and schedules sync.
    func handleLocalPreferenceChange() {
        guard let currentKey = currentPreferencesOwnerKey else { return }
        
        Log.debug("FoodNotesStore", "handleLocalPreferenceChange: Updating for \(currentKey)")
        
        // 1. Update Cache
        memberPreferencesCache[currentKey] = onboardingStore.preferences
        
        // 2. Optimistically update Associations and Canvas
        // We can do this by rebuilding or by diffing. 
        // For robustness, let's use the diff logic from applyLocalPreferencesOptimistic 
        // but adapted to use the cache as the source of truth.
        updateAssociationsAndCanvas(for: currentKey, with: onboardingStore.preferences)
        
        // 3. Schedule Sync
        scheduleSync(for: currentKey)
    }
    
    // Kept for compatibility with View calls, but delegates to handleLocalPreferenceChange
    func applyLocalPreferencesOptimistic() {
        handleLocalPreferenceChange()
    }
    
    // Kept for compatibility with View calls
    func updateFoodNotes() {
        // No-op, handled by handleLocalPreferenceChange
    }
    
    // MARK: - Internal Logic
    
    private func updateAssociationsAndCanvas(for memberKey: String, with newPrefs: Preferences) {
        // This is the same logic as before, but we know exactly who we are updating.
        var newAssociations = itemMemberAssociations
        var newCanvas = canvasPreferences
        
        for step in onboardingStore.dynamicSteps {
            let sectionName = step.header.name
            let localPreference = newPrefs.sections[sectionName]
            
            // 1. Identify what the member currently has in associations
            let serverItemsForSection = newAssociations[sectionName] ?? [:]
            let serverSelectedItems = serverItemsForSection.filter { $0.value.contains(memberKey) }.map { $0.key }
            let serverSelectedSet = Set(serverSelectedItems)
            
            // 2. Identify what the member has in newPrefs
            var localSelectedSet = Set<String>()
            if case .list(let items) = localPreference {
                localSelectedSet = Set(items)
            } else if case .nested(let nestedDict) = localPreference {
                localSelectedSet = Set(nestedDict.values.flatMap { $0 })
            }
            
            // 3. Compute diffs
            let toAdd = localSelectedSet.subtracting(serverSelectedSet)
            let toRemove = serverSelectedSet.subtracting(localSelectedSet)
            
            // 4. Handle Removals
            for item in toRemove {
                if var members = newAssociations[sectionName]?[item] {
                    members.removeAll { $0 == memberKey }
                    if members.isEmpty {
                        newAssociations[sectionName]?[item] = nil
                        // Remove from canvas
                        removeFromCanvas(canvas: &newCanvas, section: sectionName, item: item)
                    } else {
                        newAssociations[sectionName]?[item] = members
                    }
                }
            }
            
            // 5. Handle Additions
            for item in toAdd {
                if !newAssociations[sectionName, default: [:]][item, default: []].contains(memberKey) {
                    newAssociations[sectionName, default: [:]][item, default: []].append(memberKey)
                }
                // Add to canvas
                addToCanvas(canvas: &newCanvas, section: sectionName, item: item, localPref: localPreference)
            }
        }
        
        itemMemberAssociations = newAssociations
        canvasPreferences = newCanvas
    }
    
    private func removeFromCanvas(canvas: inout Preferences, section: String, item: String) {
        switch canvas.sections[section] {
        case .list(var items):
            items.removeAll { $0 == item }
            canvas.sections[section] = items.isEmpty ? nil : .list(items)
        case .nested(var nestedDict):
            for (nestedKey, var items) in nestedDict {
                items.removeAll { $0 == item }
                nestedDict[nestedKey] = items.isEmpty ? nil : items
            }
            let cleaned = nestedDict.compactMapValues { $0 }
            canvas.sections[section] = cleaned.isEmpty ? nil : .nested(cleaned)
        case nil:
            break
        }
    }
    
    private func addToCanvas(canvas: inout Preferences, section: String, item: String, localPref: PreferenceValue?) {
        if case .nested(let localNested) = localPref {
            if let nestedKey = localNested.first(where: { $0.value.contains(item) })?.key {
                if case .nested(var existingNested) = canvas.sections[section] {
                    var items = existingNested[nestedKey] ?? []
                    if !items.contains(item) {
                        items.append(item)
                        existingNested[nestedKey] = items
                    }
                    canvas.sections[section] = .nested(existingNested)
                } else {
                    canvas.sections[section] = .nested([nestedKey: [item]])
                }
            }
        } else {
            if case .list(var existingItems) = canvas.sections[section] {
                if !existingItems.contains(item) {
                    existingItems.append(item)
                    canvas.sections[section] = .list(existingItems)
                }
            } else {
                canvas.sections[section] = .list([item])
            }
        }
    }
    
    private func rebuildAssociationsAndCanvasFromCache() {
        var associations: [String: [String: [String]]] = [:]
        var unifiedContent: [String: Any] = [:] // We can reuse the buildContent logic if we want, or just manual
        
        // We need to merge all cached preferences into one canvas view
        // And build associations
        
        var newCanvas = Preferences()
        
        for (memberKey, prefs) in memberPreferencesCache {
            updateAssociationsAndCanvas(for: memberKey, with: prefs)
        }
    }
    
    // MARK: - Sync
    
    private func scheduleSync(for memberKey: String) {
        pendingSyncMembers.insert(memberKey)
        syncDebounceTask?.cancel()
        
        syncDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
            if Task.isCancelled { return }
            await performPendingSyncs()
        }
    }
    
    private func performPendingSyncs() async {
        guard !isSyncing else { return }
        let members = pendingSyncMembers
        pendingSyncMembers.removeAll()

        isSyncing = true
        defer { isSyncing = false }

        for memberKey in members {
            await syncMember(memberKey)
        }

        // After all syncs complete, refresh the summary
        refreshSummary()
    }
    
    private func syncMember(_ memberKey: String) async {
        guard let prefs = memberPreferencesCache[memberKey] else { return }

        Log.debug("FoodNotesStore", "📤 [FoodNotesStore] syncMember: Syncing \(memberKey)")

        var content = buildContentFromPreferences(preferences: prefs, dynamicSteps: onboardingStore.dynamicSteps)

        // Preserve misc notes that were set by IngrediBot
        if let miscNotes = memberMiscNotes[memberKey], !miscNotes.isEmpty {
            var preferencesDict = content["preferences"] as? [String: Any] ?? [:]
            preferencesDict["misc"] = miscNotes
            content["preferences"] = preferencesDict
        }

        let isEveryone = (memberKey == "Everyone")
        var version = isEveryone ? familyVersion : (memberVersions[memberKey] ?? 0)

        do {
            let response: WebService.FoodNotesResponse
            if !isEveryone {
                response = try await webService.updateMemberFoodNotes(
                    memberId: memberKey,
                    content: content,
                    version: version
                )
                memberVersions[memberKey] = response.version
            } else {
                response = try await webService.updateFoodNotes(content: content, version: version)
                familyVersion = response.version
            }
            Log.debug("FoodNotesStore", "✅ [FoodNotesStore] syncMember: Success \(memberKey) v\(response.version)")
        } catch let error as WebService.VersionMismatchError {
            Log.warning("FoodNotesStore", "⚠️ [FoodNotesStore] syncMember: Version mismatch \(memberKey)")
            // Re-extract misc from server's current content before retrying
            memberMiscNotes[memberKey] = extractMiscNotes(from: error.currentNote.content)
            if isEveryone { familyVersion = error.currentNote.version }
            else { memberVersions[memberKey] = error.currentNote.version }
            await syncMember(memberKey) // Retry
        } catch {
            Log.error("FoodNotesStore", "❌ [FoodNotesStore] syncMember: Failed \(error)")
        }
    }
    
    // MARK: - Helpers
    
    func convertContentToPreferences(content: [String: Any], dynamicSteps: [DynamicStep]) -> Preferences {
        var preferences = Preferences()
        for (stepId, stepContent) in content {
            guard let step = dynamicSteps.first(where: { $0.id == stepId }) else { continue }
            let sectionName = step.header.name
            
            if let itemsArray = stepContent as? [[String: Any]] {
                let itemNames = itemsArray.compactMap { $0["name"] as? String }
                if !itemNames.isEmpty { preferences.sections[sectionName] = .list(itemNames) }
            } else if let nestedDict = stepContent as? [String: Any] {
                var prefNested: [String: [String]] = [:]
                for (key, val) in nestedDict {
                    if let arr = val as? [[String: Any]] {
                        let names = arr.compactMap { $0["name"] as? String }
                        if !names.isEmpty { prefNested[key] = names }
                    }
                }
                if !prefNested.isEmpty { preferences.sections[sectionName] = .nested(prefNested) }
            }
        }
        return preferences
    }
    
    func buildContentFromPreferences(preferences: Preferences, dynamicSteps: [DynamicStep]) -> [String: Any] {
        var content: [String: Any] = [:]
        for step in dynamicSteps {
            let sectionName = step.header.name
            guard let val = preferences.sections[sectionName] else {
                // Empty section
                content[step.id] = (step.type == .type1) ? [[String:Any]]() : [String:Any]()
                continue
            }
            
            switch val {
            case .list(let items):
                let arr = items.map { name in
                    let icon = step.content.options?.first(where: { $0.name == name })?.icon ?? ""
                    return ["name": name, "iconName": icon]
                }
                content[step.id] = arr
            case .nested(let nested):
                var nestedContent: [String: Any] = [:]
                // Logic to map nested items to their structure (subSteps or regions)
                // Simplified for brevity, assuming structure matches keys
                for (key, items) in nested {
                    let arr = items.map { name in
                        // Icon lookup would go here
                        return ["name": name, "iconName": ""]
                    }
                    nestedContent[key] = arr
                }
                content[step.id] = nestedContent
            }
        }
        return content
    }
    
    private func extractMiscNotes(from content: [String: Any]) -> [String] {
        guard let preferences = content["preferences"] as? [String: Any],
              let misc = preferences["misc"] as? [String] else {
            return []
        }
        return misc
    }

    // Stub for loadFoodNotesForMember/Family if views still call them (they shouldn't with new logic)
    func loadFoodNotesForMember(memberId: String) async {}
    func loadFoodNotesForFamily() async {}
}
