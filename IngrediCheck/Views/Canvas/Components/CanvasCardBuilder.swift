//
//  CanvasCardBuilder.swift
//  IngrediCheck
//
//  Shared utility for building canvas cards and chips.
//  Consolidates common logic from MainCanvasView and EditableCanvasView.
//

import Foundation

/// Utility struct for building canvas cards and chips
@MainActor
struct CanvasCardBuilder {

    // MARK: - Icon

    /// Get icon for a step
    static func icon(for stepId: String, store: Onboarding) -> String {
        if let step = store.step(for: stepId),
           let icon = step.header.iconURL,
           !icon.isEmpty {
            return icon
        }
        return "allergies"
    }

    // MARK: - Flat Chips (Type-1 steps)

    /// Build flat chips for a section (Type-1 steps like Allergies, Intolerances)
    /// - Parameters:
    ///   - stepId: The step ID to build chips for
    ///   - sectionKey: The section name key for item associations lookup
    ///   - foodNotesStore: The food notes store containing preferences
    ///   - store: The onboarding store with step definitions
    ///   - filterMemberId: Optional member ID to filter items by
    /// - Returns: Array of ChipsModel or nil if no items
    static func chips(
        for stepId: String,
        sectionKey: String,
        foodNotesStore: FoodNotesStore?,
        store: Onboarding,
        filterMemberId: UUID? = nil
    ) -> [ChipsModel]? {
        guard let step = store.step(for: stepId) else { return nil }
        let sectionName = step.header.name

        // Use canvasPreferences for union view (Everyone + all members)
        guard let foodNotesStore = foodNotesStore,
              let value = foodNotesStore.canvasPreferences.sections[sectionName],
              case .list(let items) = value else {
            return nil
        }

        // Filter items by selected member if one is selected
        let filteredItems: [String]
        if let filterMemberId = filterMemberId {
            let memberIdString = filterMemberId.uuidString.lowercased()
            filteredItems = items.filter { itemName in
                if let memberIds = foodNotesStore.itemMemberAssociations[sectionKey]?[itemName] {
                    // Show items explicitly associated with this member
                    return memberIds.contains(memberIdString)
                }
                return false
            }
        } else {
            // No member selected, show all items (union view)
            filteredItems = items
        }

        guard !filteredItems.isEmpty else { return nil }

        // Get icons from step options
        let options = step.content.options ?? []
        return filteredItems.compactMap { itemName -> ChipsModel? in
            if let option = options.first(where: { $0.name == itemName }) {
                return ChipsModel(name: option.name, icon: option.icon)
            }
            return ChipsModel(name: itemName, icon: nil)
        }
    }

    // MARK: - Sectioned Chips (Type-2 and Type-3 steps)

    /// Build sectioned chips for Type-2 (subSteps) and Type-3 (regions) steps
    /// - Parameters:
    ///   - stepId: The step ID to build chips for
    ///   - sectionKey: The section name key for item associations lookup
    ///   - foodNotesStore: The food notes store containing preferences
    ///   - store: The onboarding store with step definitions
    ///   - filterMemberId: Optional member ID to filter items by
    /// - Returns: Array of SectionedChipModel or nil if no items
    static func sectionedChips(
        for stepId: String,
        sectionKey: String,
        foodNotesStore: FoodNotesStore?,
        store: Onboarding,
        filterMemberId: UUID? = nil
    ) -> [SectionedChipModel]? {
        guard let step = store.step(for: stepId) else { return nil }
        let sectionName = step.header.name

        // Use canvasPreferences for union view
        guard let foodNotesStore = foodNotesStore,
              let value = foodNotesStore.canvasPreferences.sections[sectionName],
              case .nested(let nestedDict) = value else {
            return nil
        }

        // Helper to filter items by selected member
        let filterItems: ([String]) -> [String] = { items in
            guard let filterMemberId = filterMemberId else { return items }
            let memberIdString = filterMemberId.uuidString.lowercased()
            return items.filter { itemName in
                if let memberIds = foodNotesStore.itemMemberAssociations[sectionKey]?[itemName] {
                    // Show items explicitly associated with this member
                    return memberIds.contains(memberIdString)
                }
                return false
            }
        }

        var sections: [SectionedChipModel] = []

        if let subSteps = step.content.subSteps {
            // MARK: Type-2 (Avoid / Lifestyle / Nutrition-style)
            for subStep in subSteps {
                guard let selectedItems = nestedDict[subStep.title],
                      !selectedItems.isEmpty else {
                    continue
                }

                // Filter items by selected member
                let filteredItems = filterItems(selectedItems)
                guard !filteredItems.isEmpty else { continue }

                // Map selected items to ChipsModel with icons
                let selectedChips: [ChipsModel] = filteredItems.compactMap { itemName in
                    if let option = subStep.options?.first(where: { $0.name == itemName }) {
                        return ChipsModel(name: option.name, icon: option.icon)
                    }
                    return ChipsModel(name: itemName, icon: nil)
                }

                if !selectedChips.isEmpty {
                    sections.append(
                        SectionedChipModel(
                            title: subStep.title,
                            subtitle: subStep.description,
                            chips: selectedChips
                        )
                    )
                }
            }
        } else if let regions = step.content.regions {
            // MARK: Type-3 (Region-style)
            for region in regions {
                guard let selectedItems = nestedDict[region.name],
                      !selectedItems.isEmpty else {
                    continue
                }

                // Filter items by selected member
                let filteredItems = filterItems(selectedItems)
                guard !filteredItems.isEmpty else { continue }

                let selectedChips: [ChipsModel] = filteredItems.compactMap { itemName in
                    if let option = region.subRegions.first(where: { $0.name == itemName }) {
                        return ChipsModel(name: option.name, icon: option.icon)
                    }
                    return ChipsModel(name: itemName, icon: nil)
                }

                if !selectedChips.isEmpty {
                    sections.append(
                        SectionedChipModel(
                            title: region.name,
                            subtitle: nil,
                            chips: selectedChips
                        )
                    )
                }
            }
        }

        return sections.isEmpty ? nil : sections
    }

    // MARK: - Section Selection Check

    /// Check if a section has any selections
    /// - Parameters:
    ///   - section: The onboarding section to check
    ///   - foodNotesStore: The food notes store containing preferences
    ///   - store: The onboarding store with step definitions
    ///   - filterMemberId: Optional member ID to filter items by
    /// - Returns: True if the section has any selected items
    static func hasSelections(
        for section: OnboardingSection,
        foodNotesStore: FoodNotesStore?,
        store: Onboarding,
        filterMemberId: UUID? = nil
    ) -> Bool {
        guard let stepId = section.screens.first?.stepId else { return false }
        let flatChips = chips(for: stepId, sectionKey: section.name, foodNotesStore: foodNotesStore, store: store, filterMemberId: filterMemberId)
        let groupedChips = sectionedChips(for: stepId, sectionKey: section.name, foodNotesStore: foodNotesStore, store: store, filterMemberId: filterMemberId)
        return (flatChips?.isEmpty == false) || (groupedChips?.isEmpty == false)
    }

    // MARK: - Build Cards

    /// Build canvas cards for display, with optional sorting by selection status
    /// - Parameters:
    ///   - store: The onboarding store with sections
    ///   - foodNotesStore: The food notes store containing preferences
    ///   - filterMemberId: Optional member ID to filter items by
    ///   - showAllSections: Whether to include empty sections (editing mode)
    ///   - sortBySelection: Whether to sort sections with selections first
    /// - Returns: Array of CanvasCardModel
    static func buildCards(
        store: Onboarding,
        foodNotesStore: FoodNotesStore?,
        filterMemberId: UUID? = nil,
        showAllSections: Bool = false,
        sortBySelection: Bool = true
    ) -> [CanvasCardModel] {
        var cards: [CanvasCardModel] = []

        // Sort sections: those with selections first, maintain original order within groups
        let sortedSections: [OnboardingSection]
        if sortBySelection {
            sortedSections = store.sections.enumerated().sorted { (a, b) in
                let hasA = hasSelections(for: a.element, foodNotesStore: foodNotesStore, store: store, filterMemberId: filterMemberId)
                let hasB = hasSelections(for: b.element, foodNotesStore: foodNotesStore, store: store, filterMemberId: filterMemberId)
                if hasA != hasB { return hasA }
                return a.offset < b.offset
            }.map { $0.element }
        } else {
            sortedSections = store.sections
        }

        for section in sortedSections {
            guard let stepId = section.screens.first?.stepId else { continue }

            let flatChips = chips(for: stepId, sectionKey: section.name, foodNotesStore: foodNotesStore, store: store, filterMemberId: filterMemberId)
            let groupedChips = sectionedChips(for: stepId, sectionKey: section.name, foodNotesStore: foodNotesStore, store: store, filterMemberId: filterMemberId)

            let hasContent = (flatChips?.isEmpty == false) || (groupedChips?.isEmpty == false)

            // In editing mode (showAllSections), show all sections
            // In onboarding mode, only show non-empty sections
            if showAllSections || hasContent {
                cards.append(
                    CanvasCardModel(
                        id: section.id,
                        title: section.name,
                        icon: icon(for: stepId, store: store),
                        stepId: stepId,
                        chips: flatChips,
                        sectionedChips: groupedChips
                    )
                )
            }
        }

        return cards
    }
}
