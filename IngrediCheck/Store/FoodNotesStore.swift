//
//  FoodNotesStore.swift
//  IngrediCheck
//
//  Created to centralize food notes/chip selection logic for reuse across the app.
//

import SwiftUI
import Observation

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
    
    /// Tracks which entity last populated `onboardingStore.preferences`.
    /// "Everyone" for family-level, or a member UUID string for member-level.
    private var currentPreferencesOwnerKey: String? = nil
    
    /// Union view preferences used for canvas/background cards (Everyone + all members)
    /// This does not change when switching members in the edit sheet.
    var canvasPreferences: Preferences = Preferences()
    
    /// Tracks which members have which items: [sectionName: [itemName: [memberIds]]]
    /// Member IDs are UUID strings or "Everyone" for family-level items.
    var itemMemberAssociations: [String: [String: [String]]] = [:]
    
    /// Loading state for food notes operations
    var isLoadingFoodNotes: Bool = false
    
    init(webService: WebService, onboardingStore: Onboarding) {
        self.webService = webService
        self.onboardingStore = onboardingStore
    }
    
    // MARK: - Loading Food Notes
    
    /// Loads the union view (family + all members) from GET /ingredicheck/family/food-notes/all.
    /// This is used for canvas/background cards that show all preferences regardless of selected member.
    func loadFoodNotesAll() async {
        print("[FoodNotesStore] loadFoodNotesAll: Starting to load food notes from backend")
        
        isLoadingFoodNotes = true
        defer { isLoadingFoodNotes = false }
        
        do {
            if let response = try await webService.fetchFoodNotesAll() {
                print("[FoodNotesStore] loadFoodNotesAll: ✅ Received food notes data")
                
                // Combine family note and member notes to get unified content
                var unifiedContent: [String: Any] = [:]
                var associations: [String: [String: [String]]] = [:]
                
                // Process family note (if exists) - these are "Everyone" level
                if let familyNote = response.familyNote {
                    familyVersion = familyNote.version
                    // Merge family note content into unified content
                    for (stepId, stepContent) in familyNote.content {
                        unifiedContent[stepId] = stepContent
                        
                        if let step = onboardingStore.dynamicSteps.first(where: { $0.id == stepId }) {
                            let sectionName = step.header.name
                            if associations[sectionName] == nil {
                                associations[sectionName] = [:]
                            }
                            
                            // Extract item names and mark as "Everyone" (family level)
                            extractItemNames(from: stepContent, sectionName: sectionName, associations: &associations, memberId: "Everyone")
                        }
                    }
                }
                
                // Process member notes - these are member-specific
                // Merge member content into unified content (combining items from all members)
                for (memberId, memberNote) in response.memberNotes {
                    let normalizedMemberId = memberId.lowercased()
                    // Track per-member versions for optimistic updates
                    memberVersions[normalizedMemberId] = memberNote.version
                    for (stepId, stepContent) in memberNote.content {
                        if let step = onboardingStore.dynamicSteps.first(where: { $0.id == stepId }) {
                            let sectionName = step.header.name
                            if associations[sectionName] == nil {
                                associations[sectionName] = [:]
                            }
                            
                            // Merge member items into unified content
                            mergeMemberContent(
                                stepId: stepId,
                                stepContent: stepContent,
                                sectionName: sectionName,
                                memberId: normalizedMemberId,
                                unifiedContent: &unifiedContent,
                                associations: &associations
                            )
                        }
                    }
                }
                
                // Convert unified content to canvasPreferences format so cards
                // always reflect Everyone + all members, independent of which
                // member is currently selected in the sheet.
                canvasPreferences = convertContentToPreferences(content: unifiedContent, dynamicSteps: onboardingStore.dynamicSteps)
                
                // Store associations
                itemMemberAssociations = associations
                
                print("[FoodNotesStore] loadFoodNotesAll: ✅ Successfully loaded and applied food notes data")
            } else {
                // No food notes exist yet, start with version 0
                familyVersion = 0
                memberVersions = [:]
                itemMemberAssociations = [:]
                print("[FoodNotesStore] loadFoodNotesAll: No existing food notes found, starting with version 0")
            }
        } catch let error as NetworkError {
                // If GET endpoint doesn't exist (404) or other errors, start with version 0
            if case .notFound = error {
                familyVersion = 0
                memberVersions = [:]
                itemMemberAssociations = [:]
                print("[FoodNotesStore] loadFoodNotesAll: GET endpoint not available (404), will detect version on first update")
            } else {
                familyVersion = 0
                memberVersions = [:]
                itemMemberAssociations = [:]
                print("[FoodNotesStore] loadFoodNotesAll: ❌ Failed to load food notes: \(error)")
            }
        } catch {
            familyVersion = 0
            memberVersions = [:]
            itemMemberAssociations = [:]
            print("[FoodNotesStore] loadFoodNotesAll: ❌ Failed to load food notes: \(error.localizedDescription)")
        }
    }
    
    /// Loads food notes for a specific member from GET /ingredicheck/family/members/:id/food-notes.
    /// This is used when a user selects a member in the carousel to edit their preferences.
    func loadFoodNotesForMember(memberId: String) async {
        print("[FoodNotesStore] loadFoodNotesForMember: Fetching member food notes for memberId=\(memberId)")
        
        do {
            if let response = try await webService.fetchMemberFoodNotes(memberId: memberId) {
                print("[FoodNotesStore] loadFoodNotesForMember: ✅ Received member food notes version=\(response.version), updatedAt=\(response.updatedAt)")
                print("[FoodNotesStore] loadFoodNotesForMember: Content keys: \(Array(response.content.keys))")
                
                // Convert and apply member-specific content to preferences
                let preferences = convertContentToPreferences(content: response.content, dynamicSteps: onboardingStore.dynamicSteps)
                onboardingStore.preferences = preferences
                onboardingStore.updateSectionCompletionStatus()
                currentPreferencesOwnerKey = memberId
                
                print("[FoodNotesStore] loadFoodNotesForMember: ✅ Applied member-specific preferences")
            } else {
                print("[FoodNotesStore] loadFoodNotesForMember: No member food notes found, clearing preferences")
                onboardingStore.preferences = Preferences()
                onboardingStore.updateSectionCompletionStatus()
                currentPreferencesOwnerKey = memberId
            }
        } catch {
            print("[FoodNotesStore] loadFoodNotesForMember: ❌ Failed to load food notes: \(error.localizedDescription)")
        }
    }
    
    /// Loads family-level food notes from GET /ingredicheck/family/food-notes.
    /// This is used when "Everyone" is selected in the carousel.
    func loadFoodNotesForFamily() async {
        print("[FoodNotesStore] loadFoodNotesForFamily: Fetching family-level food notes")
        
        do {
            if let response = try await webService.fetchFoodNotes() {
                print("[FoodNotesStore] loadFoodNotesForFamily: ✅ Received family food notes version=\(response.version), updatedAt=\(response.updatedAt)")
                print("[FoodNotesStore] loadFoodNotesForFamily: Content keys: \(Array(response.content.keys))")
                
                // Convert and apply family-level content to preferences
                let preferences = convertContentToPreferences(content: response.content, dynamicSteps: onboardingStore.dynamicSteps)
                onboardingStore.preferences = preferences
                onboardingStore.updateSectionCompletionStatus()
                currentPreferencesOwnerKey = "Everyone"
                familyVersion = response.version
                
                print("[FoodNotesStore] loadFoodNotesForFamily: ✅ Applied family-level preferences")
            } else {
                print("[FoodNotesStore] loadFoodNotesForFamily: No family food notes found, clearing preferences")
                onboardingStore.preferences = Preferences()
                onboardingStore.updateSectionCompletionStatus()
                currentPreferencesOwnerKey = "Everyone"
                familyVersion = 0
            }
        } catch {
            print("[FoodNotesStore] loadFoodNotesForFamily: ❌ Failed to load food notes: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Updating Food Notes
    
    /// Applies the current in-memory preferences for the active selection (Everyone or a member)
    /// to the canvas union view **optimistically**, without waiting for the backend.
    ///
    /// - If `selectedMemberId == nil`, we treat this as the special "Everyone" member key.
    /// - For each section:
    ///   - We derive the server's current selection for that member from `itemMemberAssociations`.
    ///   - We derive the local selection from `onboardingStore.preferences`.
    ///   - We compute added/removed items and update:
    ///       - `itemMemberAssociations[section][item]`
    ///       - `canvasPreferences.sections[section]`
    ///
    /// This preserves other members' selections and keeps the union view stable while edits happen.
    func applyLocalPreferencesOptimistic(selectedMemberId: UUID?) {
        let memberKey = selectedMemberId?.uuidString.lowercased() ?? "Everyone"
        print("[FoodNotesStore] applyLocalPreferencesOptimistic: Applying local preferences for memberKey=\(memberKey)")
        
        // Work on mutable copies so we can reason clearly, then assign back atomically.
        var newCanvas = canvasPreferences
        var newAssociations = itemMemberAssociations
        
        for step in onboardingStore.dynamicSteps {
            let sectionName = step.header.name
            
            // Local selection for this member in this section (may be nil)
            switch onboardingStore.preferences.sections[sectionName] {
            case .list(let localItems):
                // Current local items for this member
                let localSet = Set(localItems)
                
                // Server-selected items for this member: from associations where this memberKey is present
                let serverItemsForSection = newAssociations[sectionName] ?? [:]
                let serverSelected = Set(
                    serverItemsForSection.compactMap { (itemName, members) in
                        members.contains(memberKey) ? itemName : nil
                    }
                )
                
                let toAdd = localSet.subtracting(serverSelected)
                let toRemove = serverSelected.subtracting(localSet)
                
                // Handle removals
                for item in toRemove {
                    // Remove this member from associations
                    if var members = newAssociations[sectionName]?[item] {
                        members.removeAll { $0 == memberKey }
                        if members.isEmpty {
                            // No members left for this item; remove it entirely from associations and canvas
                            newAssociations[sectionName]?[item] = nil
                            
                            if case .list(var existingItems) = newCanvas.sections[sectionName] {
                                existingItems.removeAll { $0 == item }
                                if existingItems.isEmpty {
                                    newCanvas.sections[sectionName] = nil
                                } else {
                                    newCanvas.sections[sectionName] = .list(existingItems)
                                }
                            }
                        } else {
                            newAssociations[sectionName]?[item] = members
                        }
                    }
                }
                
                // Handle additions
                for item in toAdd {
                    // Ensure the item exists in associations
                    if newAssociations[sectionName] == nil {
                        newAssociations[sectionName] = [:]
                    }
                    if newAssociations[sectionName]?[item] == nil {
                        newAssociations[sectionName]?[item] = []
                    }
                    if !newAssociations[sectionName]![item]!.contains(memberKey) {
                        newAssociations[sectionName]![item]!.append(memberKey)
                    }
                    
                    // Ensure the item exists in canvas list
                    if case .list(var existingItems) = newCanvas.sections[sectionName] {
                        if !existingItems.contains(item) {
                            existingItems.append(item)
                            newCanvas.sections[sectionName] = .list(existingItems)
                        }
                    } else if newCanvas.sections[sectionName] == nil {
                        newCanvas.sections[sectionName] = .list([item])
                    }
                }
                
            case .nested(let localNested):
                // Nested sections (type-2/type-3)
                
                // Build serverSelected as a map nestedKey -> Set(items where memberKey present)
                var serverSelectedNested: [String: Set<String>] = [:]
                let serverItemsForSection = newAssociations[sectionName] ?? [:]
                
                // To compute serverSelectedNested we need to know, for each nested group,
                // which items belong there. We can derive from canvasPreferences structure.
                if case .nested(let existingNested) = newCanvas.sections[sectionName] {
                    for (nestedKey, items) in existingNested {
                        let selectedItemsForMember = items.filter { itemName in
                            serverItemsForSection[itemName]?.contains(memberKey) == true
                        }
                        if !selectedItemsForMember.isEmpty {
                            serverSelectedNested[nestedKey] = Set(selectedItemsForMember)
                        }
                    }
                }
                
                // Process each nested key in localNested
                for (nestedKey, localItems) in localNested {
                    let localSet = Set(localItems)
                    let serverSet = serverSelectedNested[nestedKey] ?? []
                    
                    let toAdd = localSet.subtracting(serverSet)
                    let toRemove = serverSet.subtracting(localSet)
                    
                    // Removals
                    for item in toRemove {
                        if var members = newAssociations[sectionName]?[item] {
                            members.removeAll { $0 == memberKey }
                            if members.isEmpty {
                                newAssociations[sectionName]?[item] = nil
                                
                                if case .nested(var existingNested) = newCanvas.sections[sectionName] {
                                    var items = existingNested[nestedKey] ?? []
                                    items.removeAll { $0 == item }
                                    if items.isEmpty {
                                        existingNested[nestedKey] = nil
                                    } else {
                                        existingNested[nestedKey] = items
                                    }
                                    
                                    // If after removal the whole nested dict is empty, clear section
                                    if existingNested.values.allSatisfy({ $0.isEmpty ?? true }) {
                                        newCanvas.sections[sectionName] = nil
                                    } else {
                                        newCanvas.sections[sectionName] = .nested(existingNested.compactMapValues { $0 })
                                    }
                                }
                            } else {
                                newAssociations[sectionName]?[item] = members
                            }
                        }
                    }
                    
                    // Additions
                    for item in toAdd {
                        if newAssociations[sectionName] == nil {
                            newAssociations[sectionName] = [:]
                        }
                        if newAssociations[sectionName]?[item] == nil {
                            newAssociations[sectionName]?[item] = []
                        }
                        if !newAssociations[sectionName]![item]!.contains(memberKey) {
                            newAssociations[sectionName]![item]!.append(memberKey)
                        }
                        
                        if case .nested(var existingNested) = newCanvas.sections[sectionName] {
                            var items = existingNested[nestedKey] ?? []
                            if !items.contains(item) {
                                items.append(item)
                                existingNested[nestedKey] = items
                            }
                            newCanvas.sections[sectionName] = .nested(existingNested)
                        } else if newCanvas.sections[sectionName] == nil {
                            newCanvas.sections[sectionName] = .nested([nestedKey: [item]])
                        }
                    }
                }
                
            case nil:
                // No local selection for this section: remove this member's contribution
                let serverItemsForSection = newAssociations[sectionName] ?? [:]
                let serverSelected = serverItemsForSection.filter { $0.value.contains(memberKey) }.map { $0.key }
                
                for item in serverSelected {
                    if var members = newAssociations[sectionName]?[item] {
                        members.removeAll { $0 == memberKey }
                        if members.isEmpty {
                            newAssociations[sectionName]?[item] = nil
                            
                            switch newCanvas.sections[sectionName] {
                            case .list(var items):
                                items.removeAll { $0 == item }
                                newCanvas.sections[sectionName] = items.isEmpty ? nil : .list(items)
                            case .nested(var nestedDict):
                                for (nestedKey, var items) in nestedDict {
                                    items.removeAll { $0 == item }
                                    nestedDict[nestedKey] = items
                                }
                                // Clean up any empty nested arrays
                                let cleaned = nestedDict.compactMapValues { $0.isEmpty ? nil : $0 }
                                newCanvas.sections[sectionName] = cleaned.isEmpty ? nil : .nested(cleaned)
                            case nil:
                                break
                            }
                        } else {
                            newAssociations[sectionName]?[item] = members
                        }
                    }
                }
            }
        }
        
        canvasPreferences = newCanvas
        itemMemberAssociations = newAssociations
        print("[FoodNotesStore] applyLocalPreferencesOptimistic: Updated canvasPreferences & itemMemberAssociations for memberKey=\(memberKey)")
    }
    
    /// Merges server-side content with new user-selected content.
    /// Strategy: for any step present in newContent, replace that step entirely on the server;
    /// steps not present in newContent are left as-is from existingContent.
    private func mergedContent(existingContent: [String: Any], newContent: [String: Any]) -> [String: Any] {
        print("🔀 [FoodNotesStore] mergedContent: Merging new content with existing server content")
        print("   → Existing content keys: \(Array(existingContent.keys))")
        print("   → New content keys: \(Array(newContent.keys))")
        
        var result = existingContent
        
        for (stepId, newStepContent) in newContent {
            print("   → Processing stepId: \(stepId)")
            
            if let itemsArray = newStepContent as? [[String: Any]] {
                // Type-1: Simple list - replace entire list with new selection
                print("     → Type-1 (list): Replacing with \(itemsArray.count) items")
                if itemsArray.isEmpty {
                    // If empty, remove the section (user deselected all items)
                    result.removeValue(forKey: stepId)
                    print("     → Removed section (empty selection)")
                } else {
                    result[stepId] = itemsArray
                    print("     → Replaced section with new items: \(itemsArray.compactMap { $0["name"] as? String })")
                }
            } else if let newNestedDict = newStepContent as? [String: Any] {
                // Type-2 or Type-3: Nested structure - replace entire nested structure
                print("     → Type-2/3 (nested): Replacing nested structure")
                print("       → New nested keys: \(Array(newNestedDict.keys))")
                
                if newNestedDict.isEmpty {
                    result.removeValue(forKey: stepId)
                    print("     → Removed section (empty nested selection)")
                } else {
                    result[stepId] = newNestedDict
                    print("     → Replaced nested structure")
                }
            }
        }
        
        print("✅ [FoodNotesStore] mergedContent: Merge complete")
        print("   → Result keys: \(Array(result.keys))")
        return result
    }
    
    /// Updates food notes (family-level or member-specific) based on selectedMemberId.
    ///
    /// `changedSections` is a set of section names (e.g. "Allergies", "Intolerances") that were
    /// actually modified by the user for this save. Only those sections will be sent to the backend;
    /// all other sections are preserved from the server's current note via merge.
    ///
    /// Flow:
    /// 1. Ensure `onboardingStore.preferences` reflects the correct source (family vs member)
    ///    based on who currently "owns" the in-memory preferences.
    /// 2. Build content from local preferences, **filtered to `changedSections` only**, and
    ///    optimistically PUT with the appropriate version.
    /// 3. If backend returns version_mismatch (409), merge currentNote.content with filtered
    ///    new content, bump version to currentNote.version, and retry PUT once with merged content.
    func updateFoodNotes(selectedMemberId: UUID?, changedSections: Set<String>) async {
        isLoadingFoodNotes = true
        defer { isLoadingFoodNotes = false }
        
        // STEP 1: Ensure preferences come from the correct note before building content,
        // but avoid clobbering fresh in-memory edits for the same owner.
        if let memberId = selectedMemberId?.uuidString.lowercased() {
            // Member-specific save
            if onboardingStore.preferences.sections.isEmpty || (currentPreferencesOwnerKey != memberId && currentPreferencesOwnerKey != nil) {
                // Either no local state yet, or local state belongs to a different owner (e.g. Everyone or another member)
                await loadFoodNotesForMember(memberId: memberId)
            }
        } else {
            // Family-level save ("Everyone")
            let familyKey = "Everyone"
            if onboardingStore.preferences.sections.isEmpty || (currentPreferencesOwnerKey != familyKey && currentPreferencesOwnerKey != nil) {
                // Either no local state yet, or local state belongs to a different owner (some member)
                await loadFoodNotesForFamily()
            }
        }
        
        // STEP 2: Build content structure dynamically from preferences
        // STEP 2: Build content structure dynamically from preferences, but only
        // for the sections that actually changed in this interaction.
        let filteredSteps = onboardingStore.dynamicSteps.filter { step in
            changedSections.contains(step.header.name)
        }
        let newContent = buildContentFromPreferences(
            preferences: onboardingStore.preferences,
            dynamicSteps: filteredSteps
        )
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        let isMemberUpdate = (selectedMemberId != nil)
        let memberKey = selectedMemberId?.uuidString.lowercased()
        
        var contentToUpdate = newContent
        var versionToUpdate = isMemberUpdate ? (memberVersions[memberKey ?? ""] ?? 0) : familyVersion
        
        // Proactively fetch and merge to avoid overwriting other sections
        if let memberId = selectedMemberId?.uuidString.lowercased() {
            print("👤 [FoodNotesStore] updateFoodNotes: Member update detected, fetching latest data to merge")
            if let latestMemberNote = try? await webService.fetchMemberFoodNotes(memberId: memberId) {
                contentToUpdate = mergedContent(existingContent: latestMemberNote.content, newContent: newContent)
                versionToUpdate = latestMemberNote.version
                memberVersions[memberId] = versionToUpdate // Update local version tracker
                print("   → Merged with latest member data (v\(versionToUpdate))")
            } else {
                print("   → No existing member data found or fetch failed, using new content (v0)")
                versionToUpdate = 0
                memberVersions[memberId] = 0
            }
        } else {
            print("👨‍👩‍👧‍👦 [FoodNotesStore] updateFoodNotes: Family update detected, fetching latest data to merge")
            if let latestFamilyNote = try? await webService.fetchFoodNotes() {
                contentToUpdate = mergedContent(existingContent: latestFamilyNote.content, newContent: newContent)
                versionToUpdate = latestFamilyNote.version
                familyVersion = versionToUpdate // Update local version tracker
                print("   → Merged with latest family data (v\(versionToUpdate))")
            } else {
                print("   → No existing family data found or fetch failed, using new content (v0)")
                versionToUpdate = 0
                familyVersion = 0
            }
        }
        
        print("💾 [FoodNotesStore] updateFoodNotes: Starting update process")
        print("   → New content keys: \(Array(contentToUpdate.keys))")
        print("   → Selected member: \(memberKey ?? "Everyone (family-level)")")
        print("   → Current optimistic version: \(versionToUpdate)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Helper to send a PUT with given content and version
        func sendUpdate(content: [String: Any], version: Int) async throws -> WebService.FoodNotesResponse {
            let maxAttempts = 3
            var attempt = 1
            
            while true {
                do {
                    if let selectedMemberId {
                        let memberIdString = selectedMemberId.uuidString
                        print("📤 [FoodNotesStore] updateFoodNotes: PUT /ingredicheck/family/members/\(memberIdString)/food-notes (attempt \(attempt)/\(maxAttempts))")
                        print("   → Version: \(version)")
                        print("   → Content keys: \(Array(content.keys))")
                        return try await webService.updateMemberFoodNotes(
                            memberId: memberIdString,
                            content: content,
                            version: version
                        )
                    } else {
                        print("📤 [FoodNotesStore] updateFoodNotes: PUT /ingredicheck/family/food-notes (attempt \(attempt)/\(maxAttempts))")
                        print("   → Version: \(version)")
                        print("   → Content keys: \(Array(content.keys))")
                        return try await webService.updateFoodNotes(content: content, version: version)
                    }
                } catch {
                    if let urlError = error as? URLError, urlError.code == .networkConnectionLost, attempt < maxAttempts {
                        attempt += 1
                        print("⚠️  [FoodNotesStore] updateFoodNotes: Network connection was lost, retrying (attempt \(attempt)/\(maxAttempts))")
                        continue
                    }
                    throw error
                }
            }
        }
        
        do {
            // 1) Optimistic update with local content and the appropriate version
            let initialResponse = try await sendUpdate(content: contentToUpdate, version: versionToUpdate)
            
            // Update version trackers
            if let memberKey {
                memberVersions[memberKey] = initialResponse.version
            } else {
                familyVersion = initialResponse.version
            }
            
            print("✅ [FoodNotesStore] updateFoodNotes: Optimistic update success")
            print("   → New version: \(initialResponse.version)")
            print("   → Updated at: \(initialResponse.updatedAt)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            
            // Refresh canvas union view after successful update
            // Note: We don't await this so the loading state can finish
            Task {
                await loadFoodNotesAll()
            }
        } catch let error as WebService.VersionMismatchError {
            // 2) Version mismatch: merge server note with new content and retry once
            print("⚠️  [FoodNotesStore] updateFoodNotes: Version mismatch (409) detected")
            print("   → Expected version: \(error.expectedVersion)")
            print("   → Current server version: \(error.currentNote.version)")
            print("   → Server content keys: \(Array(error.currentNote.content.keys))")
            
            let serverContent = error.currentNote.content
            let merged = mergedContent(existingContent: serverContent, newContent: newContent)
            
            // Refresh appropriate version tracker from server
            let retryVersion = error.currentNote.version
            if let memberKey {
                memberVersions[memberKey] = retryVersion
            } else {
                familyVersion = retryVersion
            }
            
            print("🔄 [FoodNotesStore] updateFoodNotes: Retrying with merged content and server version")
            print("   → Retry version: \(retryVersion)")
            
            do {
                let retryResponse = try await sendUpdate(content: merged, version: retryVersion)
                if let memberKey {
                    memberVersions[memberKey] = retryResponse.version
                } else {
                    familyVersion = retryResponse.version
                }
                print("✅ [FoodNotesStore] updateFoodNotes: Retry success after merge")
                print("   → New version: \(retryResponse.version)")
                print("   → Updated at: \(retryResponse.updatedAt)")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                
                Task {
                    await loadFoodNotesAll()
                }
            } catch {
                print("❌ [FoodNotesStore] updateFoodNotes: Failed on retry after merge: \(error.localizedDescription)")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            }
        } catch {
            if let networkError = error as? NetworkError {
                switch networkError {
                case .invalidResponse(let statusCode):
                    print("❌ [FoodNotesStore] updateFoodNotes: Failed - Invalid response: \(statusCode)")
                case .authError:
                    print("❌ [FoodNotesStore] updateFoodNotes: Failed - Authentication error")
                case .decodingError:
                    print("❌ [FoodNotesStore] updateFoodNotes: Failed - Decoding error")
                case .badUrl:
                    print("❌ [FoodNotesStore] updateFoodNotes: Failed - Bad URL")
                case .notFound(let message):
                    print("❌ [FoodNotesStore] updateFoodNotes: Failed - Not found: \(message)")
                }
            } else {
                print("❌ [FoodNotesStore] updateFoodNotes: Failed - Error: \(error.localizedDescription)")
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
    }
    
    // MARK: - Content Conversion Helpers
    
    /// Converts backend food-notes `content` into `Preferences` format.
    /// Used for both canvas union view and member/family-specific preferences.
    func convertContentToPreferences(content: [String: Any], dynamicSteps: [DynamicStep]) -> Preferences {
        var preferences = Preferences()
        
        // Iterate through content keys (which are step IDs)
        for (stepId, stepContent) in content {
            // Find the step by ID to get the section name
            guard let step = dynamicSteps.first(where: { $0.id == stepId }) else {
                continue
            }
            
            let sectionName = step.header.name
            
            // Check if content is an array (type-1) or nested object (type-2 or type-3)
            if let itemsArray = stepContent as? [[String: Any]] {
                // Type-1: Simple list
                let itemNames = itemsArray.compactMap { item -> String? in
                    if let name = item["name"] as? String {
                        return name
                    }
                    return nil
                }
                
                if !itemNames.isEmpty {
                    preferences.sections[sectionName] = .list(itemNames)
                }
            } else if let nestedDict = stepContent as? [String: Any] {
                // Type-2 or Type-3: Nested structure
                var preferencesNestedDict: [String: [String]] = [:]
                
                for (nestedKey, nestedValue) in nestedDict {
                    if let itemsArray = nestedValue as? [[String: Any]] {
                        let itemNames = itemsArray.compactMap { item -> String? in
                            if let name = item["name"] as? String {
                                return name
                            }
                            return nil
                        }
                        
                        if !itemNames.isEmpty {
                            preferencesNestedDict[nestedKey] = itemNames
                        }
                    }
                }
                
                if !preferencesNestedDict.isEmpty {
                    preferences.sections[sectionName] = .nested(preferencesNestedDict)
                }
            }
        }
        
        return preferences
    }
    
    /// Builds backend content format from `Preferences` for API updates.
    func buildContentFromPreferences(preferences: Preferences, dynamicSteps: [DynamicStep]) -> [String: Any] {
        var content: [String: Any] = [:]
        
        // Iterate through all dynamic steps to build content
        for step in dynamicSteps {
            let sectionName = step.header.name
            
            guard let preferenceValue = preferences.sections[sectionName] else {
                // If preference is missing, it means the section is cleared.
                // We must still include the key with an empty value so mergedContent knows to remove it.
                if step.type == .type1 {
                    content[step.id] = [[String: Any]]()
                } else {
                    content[step.id] = [String: Any]()
                }
                continue
            }
            
            switch preferenceValue {
            case .list(let items):
                // Simple list - convert to array of objects with iconName and name
                let itemsArray = items.compactMap { itemName -> [String: String]? in
                    // Find icon from step options
                    let icon = step.content.options?.first(where: { $0.name == itemName })?.icon ?? ""
                    return [
                        "iconName": icon,
                        "name": itemName
                    ]
                }
                
                // Always set the key, even if itemsArray is empty
                content[step.id] = itemsArray
                
            case .nested(let nestedDict):
                // Nested structure - for type-2 steps (Avoid, LifeStyle, Nutrition)
                var nestedContent: [String: Any] = [:]
                
                if let subSteps = step.content.subSteps {
                    for subStep in subSteps {
                        if let items = nestedDict[subStep.title], !items.isEmpty {
                            let itemsArray = items.compactMap { itemName -> [String: String]? in
                                let icon = subStep.options?.first(where: { $0.name == itemName })?.icon ?? ""
                                return [
                                    "iconName": icon,
                                    "name": itemName
                                ]
                            }
                            
                            if !itemsArray.isEmpty {
                                nestedContent[subStep.title] = itemsArray
                            }
                        }
                    }
                } else if step.type == .type3 {
                    // Type-3 (Region) - regions with subRegions
                    for (regionName, items) in nestedDict {
                        if !items.isEmpty {
                            let itemsArray = items.compactMap { itemName -> [String: String]? in
                                // Find icon from regions structure
                                var icon = ""
                                if let region = step.content.regions?.first(where: { $0.name == regionName }) {
                                    icon = region.subRegions.first(where: { $0.name == itemName })?.icon ?? ""
                                }
                                return [
                                    "iconName": icon,
                                    "name": itemName
                                ]
                            }
                            
                            if !itemsArray.isEmpty {
                                nestedContent[regionName] = itemsArray
                            }
                        }
                    }
                }
                
                // Always set the key, even if nestedContent is empty
                content[step.id] = nestedContent
            }
        }
        
        return content
    }
    
    // MARK: - Private Helpers
    
    /// Extracts item names from step content and adds them to associations.
    private func extractItemNames(
        from stepContent: Any,
        sectionName: String,
        associations: inout [String: [String: [String]]],
        memberId: String
    ) {
        if let itemsArray = stepContent as? [[String: Any]] {
            for item in itemsArray {
                if let itemName = item["name"] as? String {
                    if associations[sectionName]?[itemName] == nil {
                        associations[sectionName]?[itemName] = []
                    }
                    if !associations[sectionName]![itemName]!.contains(memberId) {
                        associations[sectionName]![itemName]!.append(memberId)
                    }
                }
            }
        } else if let nestedDict = stepContent as? [String: Any] {
            for (_, nestedValue) in nestedDict {
                if let itemsArray = nestedValue as? [[String: Any]] {
                    for item in itemsArray {
                        if let itemName = item["name"] as? String {
                            if associations[sectionName]?[itemName] == nil {
                                associations[sectionName]?[itemName] = []
                            }
                            if !associations[sectionName]![itemName]!.contains(memberId) {
                                associations[sectionName]![itemName]!.append(memberId)
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Merges member content into unified content and tracks associations.
    private func mergeMemberContent(
        stepId: String,
        stepContent: Any,
        sectionName: String,
        memberId: String,
        unifiedContent: inout [String: Any],
        associations: inout [String: [String: [String]]]
    ) {
        if let itemsArray = stepContent as? [[String: Any]] {
            // Type-1: Simple list - merge items
            var existingItems = unifiedContent[stepId] as? [[String: Any]] ?? []
            var existingItemNames = Set(existingItems.compactMap { $0["name"] as? String })
            
            for item in itemsArray {
                if let itemName = item["name"] as? String {
                    if !existingItemNames.contains(itemName) {
                        existingItems.append(item)
                        existingItemNames.insert(itemName)
                    }
                    
                    // Track member association
                    if associations[sectionName]?[itemName] == nil {
                        associations[sectionName]?[itemName] = []
                    }
                    if !associations[sectionName]![itemName]!.contains(memberId) {
                        associations[sectionName]![itemName]!.append(memberId)
                    }
                }
            }
            unifiedContent[stepId] = existingItems
        } else if let nestedDict = stepContent as? [String: Any] {
            // Type-2 or Type-3: Nested structure - merge nested items
            var existingNested = unifiedContent[stepId] as? [String: Any] ?? [:]
            
            for (nestedKey, nestedValue) in nestedDict {
                if let itemsArray = nestedValue as? [[String: Any]] {
                    var existingItems = existingNested[nestedKey] as? [[String: Any]] ?? []
                    var existingItemNames = Set(existingItems.compactMap { $0["name"] as? String })
                    
                    for item in itemsArray {
                        if let itemName = item["name"] as? String {
                            if !existingItemNames.contains(itemName) {
                                existingItems.append(item)
                                existingItemNames.insert(itemName)
                            }
                            
                            // Track member association
                            if associations[sectionName]?[itemName] == nil {
                                associations[sectionName]?[itemName] = []
                            }
                            if !associations[sectionName]![itemName]!.contains(memberId) {
                                associations[sectionName]![itemName]!.append(memberId)
                            }
                        }
                    }
                    existingNested[nestedKey] = existingItems
                }
            }
            unifiedContent[stepId] = existingNested
        }
    }
}

