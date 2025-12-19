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
    
    /// Current version for optimistic updates (family-level or member-specific)
    var currentVersion: Int = 0
    
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
                    currentVersion = familyNote.version
                    
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
                    // Use the highest version from member notes if no family note
                    if response.familyNote == nil {
                        currentVersion = max(currentVersion, memberNote.version)
                    }
                    
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
                                memberId: memberId,
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
                
                // If an item has both "Everyone" and specific members associated,
                // prefer the specific members and drop the "Everyone" tag so
                // the UI shows the correct per-member icons.
                for (sectionName, items) in associations {
                    for (itemName, members) in items {
                        let specificMembers = members.filter { $0 != "Everyone" }
                        if !specificMembers.isEmpty {
                            associations[sectionName]?[itemName] = specificMembers
                        }
                    }
                }
                
                // Store associations after cleanup
                itemMemberAssociations = associations
                
                print("[FoodNotesStore] loadFoodNotesAll: ✅ Successfully loaded and applied food notes data")
            } else {
                // No food notes exist yet, start with version 0
                currentVersion = 0
                itemMemberAssociations = [:]
                print("[FoodNotesStore] loadFoodNotesAll: No existing food notes found, starting with version 0")
            }
        } catch let error as NetworkError {
            // If GET endpoint doesn't exist (404) or other errors, start with version 0
            if case .notFound = error {
                currentVersion = 0
                itemMemberAssociations = [:]
                print("[FoodNotesStore] loadFoodNotesAll: GET endpoint not available (404), will detect version on first update")
            } else {
                currentVersion = 0
                itemMemberAssociations = [:]
                print("[FoodNotesStore] loadFoodNotesAll: ❌ Failed to load food notes: \(error)")
            }
        } catch {
            currentVersion = 0
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
                
                print("[FoodNotesStore] loadFoodNotesForMember: ✅ Applied member-specific preferences")
            } else {
                print("[FoodNotesStore] loadFoodNotesForMember: No member food notes found, clearing preferences")
                onboardingStore.preferences = Preferences()
                onboardingStore.updateSectionCompletionStatus()
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
                
                print("[FoodNotesStore] loadFoodNotesForFamily: ✅ Applied family-level preferences")
            } else {
                print("[FoodNotesStore] loadFoodNotesForFamily: No family food notes found, clearing preferences")
                onboardingStore.preferences = Preferences()
                onboardingStore.updateSectionCompletionStatus()
            }
        } catch {
            print("[FoodNotesStore] loadFoodNotesForFamily: ❌ Failed to load food notes: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Updating Food Notes
    
    /// Fetches current data from backend and merges it with new user-selected data.
    /// This ensures PUT requests don't replace existing data, but merge with it.
    private func fetchAndMergeContent(selectedMemberId: UUID?, newContent: [String: Any]) async throws -> [String: Any] {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔄 [FoodNotesStore] fetchAndMergeContent: Starting fetch and merge process")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        var existingContent: [String: Any] = [:]
        var fetchedVersion: Int = currentVersion
        
        // Fetch existing data from backend
        do {
            if let selectedMemberId = selectedMemberId {
                let memberIdString = selectedMemberId.uuidString
                print("📥 [FoodNotesStore] fetchAndMergeContent: Fetching existing data for memberId=\(memberIdString)")
                print("   → GET /ingredicheck/family/members/\(memberIdString)/food-notes")
                
                if let response = try await webService.fetchMemberFoodNotes(memberId: memberIdString) {
                    existingContent = response.content
                    fetchedVersion = response.version
                    print("✅ [FoodNotesStore] fetchAndMergeContent: Fetched existing member data")
                    print("   → Version: \(fetchedVersion)")
                    print("   → Existing content keys: \(Array(existingContent.keys))")
                } else {
                    print("ℹ️  [FoodNotesStore] fetchAndMergeContent: No existing member data found (starting fresh)")
                }
            } else {
                print("📥 [FoodNotesStore] fetchAndMergeContent: Fetching existing data for family (Everyone)")
                print("   → GET /ingredicheck/family/food-notes")
                
                if let response = try await webService.fetchFoodNotes() {
                    existingContent = response.content
                    fetchedVersion = response.version
                    print("✅ [FoodNotesStore] fetchAndMergeContent: Fetched existing family data")
                    print("   → Version: \(fetchedVersion)")
                    print("   → Existing content keys: \(Array(existingContent.keys))")
                } else {
                    print("ℹ️  [FoodNotesStore] fetchAndMergeContent: No existing family data found (starting fresh)")
                }
            }
        } catch {
            print("⚠️  [FoodNotesStore] fetchAndMergeContent: Failed to fetch existing data: \(error.localizedDescription)")
            print("   → Will proceed with new content only (may overwrite existing data)")
        }
        
        // Update current version to match fetched version
        currentVersion = fetchedVersion
        
        // Merge new content with existing content
        // Strategy: Replace entire sections that are in newContent, keep other sections unchanged
        print("🔀 [FoodNotesStore] fetchAndMergeContent: Merging new content with existing content")
        print("   → New content keys: \(Array(newContent.keys))")
        print("   → Existing content keys: \(Array(existingContent.keys))")
        
        var mergedContent: [String: Any] = existingContent
        
        // For each step in newContent, replace the entire section (this handles deselections correctly)
        // Sections not in newContent remain unchanged from existingContent
        for (stepId, newStepContent) in newContent {
            print("   → Processing stepId: \(stepId)")
            
            if let itemsArray = newStepContent as? [[String: Any]] {
                // Type-1: Simple list - replace entire list with new selection
                print("     → Type-1 (list): Replacing with \(itemsArray.count) items")
                if itemsArray.isEmpty {
                    // If empty, remove the section (user deselected all items)
                    mergedContent.removeValue(forKey: stepId)
                    print("     → Removed section (empty selection)")
                } else {
                    mergedContent[stepId] = itemsArray
                    print("     → Replaced section with new items: \(itemsArray.compactMap { $0["name"] as? String })")
                }
                
            } else if let newNestedDict = newStepContent as? [String: Any] {
                // Type-2 or Type-3: Nested structure - replace entire nested structure
                print("     → Type-2/3 (nested): Replacing nested structure")
                print("       → New nested keys: \(Array(newNestedDict.keys))")
                
                if newNestedDict.isEmpty {
                    // If empty, remove the section
                    mergedContent.removeValue(forKey: stepId)
                    print("     → Removed section (empty nested selection)")
                } else {
                    // Replace the entire nested structure
                    mergedContent[stepId] = newNestedDict
                    print("     → Replaced nested structure")
                }
            }
        }
        
        print("✅ [FoodNotesStore] fetchAndMergeContent: Merge complete")
        print("   → Merged content keys: \(Array(mergedContent.keys))")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        return mergedContent
    }
    
    /// Updates food notes (family-level or member-specific) based on selectedMemberId.
    /// Automatically handles version mismatches and retries.
    /// Fetches existing data and merges with new data before sending PUT request.
    func updateFoodNotes(selectedMemberId: UUID?) async {
        // Build content structure dynamically from preferences
        let newContent = buildContentFromPreferences(preferences: onboardingStore.preferences, dynamicSteps: onboardingStore.dynamicSteps)
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("💾 [FoodNotesStore] updateFoodNotes: Starting update process")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("   → New content keys: \(Array(newContent.keys))")
        print("   → Selected member: \(selectedMemberId?.uuidString ?? "Everyone (family-level)")")
        
        // Fetch existing data and merge with new content
        let mergedContent: [String: Any]
        do {
            mergedContent = try await fetchAndMergeContent(selectedMemberId: selectedMemberId, newContent: newContent)
        } catch {
            print("❌ [FoodNotesStore] updateFoodNotes: Failed to fetch and merge content: \(error.localizedDescription)")
            print("   → Falling back to using new content only")
            mergedContent = newContent
        }
        
        do {
            // Decide whether to update at family-level or member-level based on selectedMemberId
            if let selectedMemberId = selectedMemberId {
                let memberIdString = selectedMemberId.uuidString
                print("📤 [FoodNotesStore] updateFoodNotes: Sending PUT request for member")
                print("   → PUT /ingredicheck/family/members/\(memberIdString)/food-notes")
                print("   → Version: \(currentVersion)")
                print("   → Merged content keys: \(Array(mergedContent.keys))")
                
                let response = try await webService.updateMemberFoodNotes(
                    memberId: memberIdString,
                    content: mergedContent,
                    version: currentVersion
                )
                
                currentVersion = response.version
                print("✅ [FoodNotesStore] updateFoodNotes: Member update success")
                print("   → New version: \(response.version)")
                print("   → Updated at: \(response.updatedAt)")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                
                // Refresh canvas union view after member update
                Task {
                    await loadFoodNotesAll()
                }
            } else {
                print("📤 [FoodNotesStore] updateFoodNotes: Sending PUT request for family (Everyone)")
                print("   → PUT /ingredicheck/family/food-notes")
                print("   → Version: \(currentVersion)")
                print("   → Merged content keys: \(Array(mergedContent.keys))")
                
                let response = try await webService.updateFoodNotes(content: mergedContent, version: currentVersion)
                
                currentVersion = response.version
                print("✅ [FoodNotesStore] updateFoodNotes: Family update success")
                print("   → New version: \(response.version)")
                print("   → Updated at: \(response.updatedAt)")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                
                // Refresh canvas union view after family-level update
                Task {
                    await loadFoodNotesAll()
                }
            }
        } catch let error as WebService.VersionMismatchError {
            // Handle version mismatch - backend provides currentNote with actual data
            print("⚠️  [FoodNotesStore] updateFoodNotes: Version mismatch detected")
            print("   → Expected version: \(error.expectedVersion)")
            print("   → Current server version: \(error.currentNote.version)")
            
            currentVersion = error.currentNote.version
            
            // Retry with the correct version using the same endpoint decision
            do {
                if let selectedMemberId = selectedMemberId {
                    let memberIdString = selectedMemberId.uuidString
                    print("🔄 [FoodNotesStore] updateFoodNotes: Retrying member-specific update")
                    print("   → Version: \(currentVersion)")
                    
                    let response = try await webService.updateMemberFoodNotes(
                        memberId: memberIdString,
                        content: mergedContent,
                        version: currentVersion
                    )
                    currentVersion = response.version
                    print("✅ [FoodNotesStore] updateFoodNotes: Member retry success")
                    print("   → New version: \(response.version)")
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    
                    Task {
                        await loadFoodNotesAll()
                    }
                } else {
                    print("🔄 [FoodNotesStore] updateFoodNotes: Retrying family-level update")
                    print("   → Version: \(currentVersion)")
                    
                    let response = try await webService.updateFoodNotes(content: mergedContent, version: currentVersion)
                    currentVersion = response.version
                    print("✅ [FoodNotesStore] updateFoodNotes: Family retry success")
                    print("   → New version: \(response.version)")
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    
                    Task {
                        await loadFoodNotesAll()
                    }
                }
            } catch {
                print("❌ [FoodNotesStore] updateFoodNotes: Failed on retry: \(error.localizedDescription)")
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
                
                if !itemsArray.isEmpty {
                    content[step.id] = itemsArray
                }
                
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
                
                if !nestedContent.isEmpty {
                    content[step.id] = nestedContent
                }
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

