//
//  EditableCanvasView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar on 15/11/25.
//

import SwiftUI
import Observation

struct EditableCanvasView: View {
    @EnvironmentObject private var store: Onboarding
    @Environment(\.dismiss) private var dismiss
    @Environment(WebService.self) private var webService
    @Environment(FamilyStore.self) private var familyStore
    @Environment(AppNavigationCoordinator.self) private var navCoordinator
    @Environment(AppState.self) private var appState

    // Optional: center a specific section when arriving here (e.g., Lifestyle/Nutrition)
    let targetSectionName: String?
    let onBack: (() -> Void)?

    @Environment(FoodNotesStore.self) private var foodNotesStore
    @State private var didFinishInitialLoad: Bool = false
    
    let titleOverride: String?
    let showBackButton: Bool
    
    @State private var tagBarScrollTarget: UUID? = nil
    @State private var isProgrammaticChange: Bool = false
    @State private var isLoadingMemberPreferences: Bool = false
    @State private var isTabBarExpanded: Bool = true
    @State private var scrollY: CGFloat = 0
    @State private var prevValue: CGFloat = 0
    @State private var maxScrollOffset: CGFloat = 0
    @State private var hasScrolledToTarget: Bool = false
    @State private var headroomCollapsed: Bool = false
    @State private var selectedMemberId: UUID? = nil // Track selected family member for filtering
    
    init(targetSectionName: String? = nil, titleOverride: String? = nil, showBackButton: Bool = true, onBack: (() -> Void)? = nil) {
        self.targetSectionName = targetSectionName
        self.titleOverride = titleOverride
        self.showBackButton = showBackButton
        self.onBack = onBack
    }
    
    private var shouldCenterLifestyleNutrition: Bool {
        guard let targetSectionName, targetSectionName.isEmpty == false else { return false }
        let t = targetSectionName.lowercased().replacingOccurrences(of: " ", with: "")
        return t.contains("lifestyle") || t.contains("nutrition")
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent
        }
        .modifier(
            ConditionalBottomTabBar(
                isEnabled: !navCoordinator.isEditSheetPresented,
                gradientColors: [
                    Color.white.opacity(0),
                    Color.white
                ]
            ) {
                TabBar(
                    isExpanded: $isTabBarExpanded,
                    onRecentScansTap: {
                        // Navigate to Recent Scans view
                        appState.navigationPath.append(HistoryRouteItem.recentScansAll)
                    }
                )
                    .fixedSize(horizontal: false, vertical: true)
            }
        )
        .background(Color.white)
        .navigationTitle(titleOverride ?? "Food Notes")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            onBack?()
        }
        .onAppear {
            // Update completion status for all sections based on their data
            store.updateSectionCompletionStatus()
        }
        .task {
            Log.debug("EditableCanvasView", "Food notes load task triggered")

            // Fetch and load food notes data when view appears
            await foodNotesStore.loadFoodNotesAll()

            // Prepare preferences for the current selection locally from the loaded data
            foodNotesStore.preparePreferencesForMember(selectedMemberId: familyStore.selectedMemberId)
            didFinishInitialLoad = true
        }
        .onChange(of: store.preferences) { _ in
            // Update completion status whenever preferences change
            store.updateSectionCompletionStatus()
            
            // If we were loading member/family preferences, this change came from a backend load.
            // DO NOT save.
            if isLoadingMemberPreferences {
                print("[EditableCanvasView] Preferences updated during load, skipping save")
                return
            }
            
            // Capture the section that just changed so we don't lose it if the user navigates
            // before the Task starts executing.
            let changedSectionName = store.currentSection.name
            let changedSections: Set<String> = [changedSectionName]
            
            print("[EditableCanvasView] Preferences changed, saving section \(changedSectionName) immediately")
            
            // Optimistically update the canvas summary view from local preferences for this member.
            foodNotesStore.applyLocalPreferencesOptimistic()

            foodNotesStore.updateFoodNotes()

            // Trigger scan history refresh when user navigates back to HomeView
            appState.needsScanHistoryRefresh = true
        }
        .onChange(of: familyStore.selectedMemberId) { newValue in
            // Don't switch members before initial load completes - it would clear preferences
            guard didFinishInitialLoad else {
                print("[EditableCanvasView] Member switch ignored - initial load not complete")
                return
            }
            // When switching members, prepare preferences locally from associations.
            print("[EditableCanvasView] Member switched to \(newValue?.uuidString ?? "Everyone"), preparing local preferences")

            // Mark as loading to prevent the onChange(of: preferences) from triggering a sync
            // for the newly loaded member's existing state.
            isLoadingMemberPreferences = true
            foodNotesStore.preparePreferencesForMember(selectedMemberId: newValue)
            isLoadingMemberPreferences = false
        }
        .onChange(of: navCoordinator.isEditSheetPresented) { oldValue, newValue in
            // When edit sheet is dismissed, flush preferences to cache first so the first selection is never lost,
            // then refresh from cache (only after initial load)
            if oldValue == true && newValue == false && didFinishInitialLoad {
                foodNotesStore.applyLocalPreferencesOptimistic()
                foodNotesStore.preparePreferencesForMember(selectedMemberId: navCoordinator.editingMemberId ?? selectedMemberId)
            }
        }
        .onDisappear {
            // Dismiss bottom sheet when view disappears (handles both back button and system swipe gesture)
            if navCoordinator.isEditSheetPresented {
                withAnimation(.easeInOut(duration: 0.2)) {
                    navCoordinator.isEditSheetPresented = false
                }
            }
        }
    }
    
    private func icon(for stepId: String) -> String {
        if let step = store.step(for: stepId),
           let icon = step.header.iconURL,
           icon.isEmpty == false {
            return icon
        }
        return "allergies"
    }
    
    // Helper function to get member identifiers for an item
    // Returns "Everyone" or member UUID strings for use in ChipMemberAvatarView
    private func getMemberIdentifiers(for sectionName: String, itemName: String) -> [String] {
        guard let memberIds = foodNotesStore.itemMemberAssociations[sectionName]?[itemName] else {
            return []
        }
        
        // Return member IDs directly (already UUID strings or "Everyone")
        // ChipMemberAvatarView will resolve these to FamilyMember objects
        return memberIds
    }
    
    private func chips(for stepId: String, sectionKey: String) -> [ChipsModel]? {
        guard let step = store.step(for: stepId) else { return nil }
        let sectionName = step.header.name
        
        // Use canvasPreferences so scroll cards always show the union view
        // (Everyone + all members) and do not change when switching member.
        guard let value = foodNotesStore.canvasPreferences.sections[sectionName],
              case .list(let items) = value else {
            return nil
        }
        
        // Filter items by selected member if one is selected
        let filteredItems: [String]
        if let selectedMemberId = selectedMemberId {
            // FoodNotesStore stores member keys lowercased.
            let memberIdString = selectedMemberId.uuidString.lowercased()
            filteredItems = items.filter { itemName in
                // IMPORTANT: itemMemberAssociations is keyed by the *card/section name* shown in UI,
                // not necessarily step.header.name. Use sectionKey to match what's used in cards.
                if let memberIds = foodNotesStore.itemMemberAssociations[sectionKey]?[itemName] {
                    // Only show items explicitly associated with this member.
                    // Exclude any items that are also tagged for "Everyone".
                    return memberIds.contains(memberIdString) && !memberIds.contains("Everyone")
                }
                return false
            }
        } else {
            // No member selected, show all items (union view)
            filteredItems = items
        }
        
        // Get icons from step options
        let options = step.content.options ?? []
        return filteredItems.compactMap { itemName -> ChipsModel? in
            if let option = options.first(where: { $0.name == itemName }) {
                return ChipsModel(name: option.name, icon: option.icon)
            }
            return ChipsModel(name: itemName, icon: nil)
        }
    }
    
    private func sectionedChips(for stepId: String, sectionKey: String) -> [SectionedChipModel]? {
        guard let step = store.step(for: stepId) else { return nil }
        let sectionName = step.header.name
        
        // Use canvasPreferences for union view
        guard let value = foodNotesStore.canvasPreferences.sections[sectionName],
              case .nested(let nestedDict) = value else {
            return nil
        }
        
        // Type-2 steps use subSteps, type-3 steps use regions. Handle both.
        var sections: [SectionedChipModel] = []
        
        // Helper to filter items by selected member
        let filterItems: ([String]) -> [String] = { items in
            guard let selectedMemberId = selectedMemberId else { return items }
            // FoodNotesStore stores member keys lowercased.
            let memberIdString = selectedMemberId.uuidString.lowercased()
            return items.filter { itemName in
                // IMPORTANT: itemMemberAssociations is keyed by the *card/section name* shown in UI.
                if let memberIds = foodNotesStore.itemMemberAssociations[sectionKey]?[itemName] {
                    return memberIds.contains(memberIdString) && !memberIds.contains("Everyone")
                }
                return false
            }
        }
        
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
    
    private func selectedCards() -> [EditableCanvasCardModel] {
        var cards: [EditableCanvasCardModel] = []
        
        for section in store.sections {
            guard let stepId = section.screens.first?.stepId else { continue }
            let rawChips = chips(for: stepId, sectionKey: section.name)
            let rawGroupedChips = sectionedChips(for: stepId, sectionKey: section.name)
            
            let chips = (rawChips?.isEmpty == false) ? rawChips : nil
            let groupedChips = (rawGroupedChips?.isEmpty == false) ? rawGroupedChips : nil
            
            cards.append(
                EditableCanvasCardModel(
                    id: section.id,
                    title: section.name,
                    icon: icon(for: stepId),
                    stepId: stepId,
                    chips: chips,
                    sectionedChips: groupedChips
                )
            )
        }
        
        return cards
    }
    
    private func openEditSheetForCurrentSection() {
        if let stepId = store.currentSection.screens.first?.stepId {
            withAnimation(.easeInOut(duration: 0.2)) {
                navCoordinator.currentEditingSectionIndex = store.currentSectionIndex
                navCoordinator.editingStepId = stepId
                navCoordinator.isEditSheetPresented = true
            }
        }
    }
    
    private func openEditSheetForSection(at index: Int) {
        guard store.sections.indices.contains(index),
              let stepId = store.sections[index].screens.first?.stepId else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            navCoordinator.currentEditingSectionIndex = index
            navCoordinator.editingStepId = stepId
            navCoordinator.isEditSheetPresented = true
        }
    }
    
    // MARK: - Food Notes API Integration
    // All food notes logic is now handled by FoodNotesStore
}

struct EditableCanvasCardModel: Identifiable {
    let id: UUID
    let title: String
    let icon: String
    let stepId: String
    let chips: [ChipsModel]?
    let sectionedChips: [SectionedChipModel]?
}

struct EditableCanvasCard: View {
    @Environment(FamilyStore.self) private var familyStore
    
    var chips: [ChipsModel]? = nil
    var sectionedChips: [SectionedChipModel]? = nil
    var title: String = "Allergies"
    var iconName: String = "allergies"
    var onEdit: (() -> Void)? = nil
    var itemMemberAssociations: [String: [String: [String]]] = [:]
    var showFamilyIcons: Bool = true
    var activeMemberId: UUID? = nil
    
    private var isEmptyState: Bool {
        let hasSectioned = (sectionedChips?.isEmpty == false)
        let hasChips = (chips?.isEmpty == false)
        return !hasSectioned && !hasChips
    }
    
    // Helper function to get member identifiers for an item
    // Returns "Everyone" or member UUID strings for use in ChipMemberAvatarView
    private func getMemberIdentifiers(for sectionName: String, itemName: String) -> [String] {
        guard let memberIds = itemMemberAssociations[sectionName]?[itemName] else {
            return []
        }
        // When a specific member is selected in the capsules row, only show THAT member’s avatar
        // (avoid showing other members who share the same preference).
        if let activeMemberId {
            // Force display to only the selected member (even if multiple members share the item).
            return [activeMemberId.uuidString]
        }
        
        // Otherwise, show all associated members ("Everyone" or member UUID strings).
        return memberIds
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(iconName)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(.grayScale110)
                        .frame(width: 18, height: 18)
                    
                    Text(title.capitalized)
                        .font(NunitoFont.semiBold.size(14))
                        .foregroundStyle(.grayScale110)
                }
                .fontWeight(.semibold)
                
                Spacer()
                
                // Edit button
                if let onEdit = onEdit {
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image("pen-line")
                                .resizable()
                                .renderingMode(.template)   // 👈 important
                                .foregroundStyle(.grayScale110)
                                .frame(width: 14, height: 14)

                            Text("Edit")
                                .font(NunitoFont.medium.size(14))
                                .foregroundStyle(Color(.grayScale110))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .foregroundStyle(.grayScale30)
                        )
                    }
                }
            }
            
            VStack(alignment: .leading) {
                if isEmptyState {
                    VStack(spacing:4) {
                        ZStack {
                            Circle()
                                .fill(Color.grayScale30.opacity(0.5))
                                .frame(width: 40, height:40)
                            Image("edit-pen")
                                .frame(width: 24, height:24)
                                .foregroundStyle(.grayScale80)
                        }
                        .padding(.top, 8)
                        
                        Text("Nothing added yet")
                            .font(NunitoFont.semiBold.size(14))
                            .foregroundStyle(.grayScale100)
                        
                        Text("You can add details anytime by tapping Edit.")
                            .font(NunitoFont.regular.size(10))
                            .foregroundStyle(.grayScale100)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, )
                    .frame(height : 100)
                } else if let sectionedChips = sectionedChips {
                    ForEach(sectionedChips) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(ManropeFont.semiBold.size(12))
                                .foregroundStyle(.grayScale150)
                            
                            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                                ForEach(section.chips) { chip in
                                    IngredientsChips(
                                        title: chip.name,
                                        bgColor: .secondary200,
                                        image: chip.icon,
                                        familyList: showFamilyIcons ? getMemberIdentifiers(for: title, itemName: chip.name) : [],
                                        outlined: false
                                    )
                                }
                            }
                        }
                    }
                } else if let chips = chips {
                    FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(chips, id: \.id) { chip in
                            IngredientsChips(
                                title: chip.name,
                                bgColor: .secondary200,
                                image: chip.icon,
                                familyList: showFamilyIcons ? getMemberIdentifiers(for: title, itemName: chip.name) : [],
                                outlined: false
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, isEmptyState ? 8 : 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 0.25)
                .foregroundStyle(.grayScale60)
        )
    }
}

// MARK: - Misc Notes Card

struct MiscNotesCard: View {
    let notes: [String]
    var onEdit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .resizable()
                        .foregroundStyle(.grayScale110)
                        .frame(width: 16, height: 18)

                    Text("Notes")
                        .font(NunitoFont.semiBold.size(14))
                        .foregroundStyle(.grayScale110)
                }
                .fontWeight(.semibold)

                Spacer()

                if let onEdit = onEdit {
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                                .resizable()
                                .foregroundStyle(.grayScale110)
                                .frame(width: 14, height: 14)

                            Text("Chat")
                                .font(NunitoFont.medium.size(14))
                                .foregroundStyle(Color(.grayScale110))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .foregroundStyle(.grayScale30)
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(NunitoFont.regular.size(14))
                            .foregroundStyle(.grayScale100)
                        Text(note)
                            .font(NunitoFont.regular.size(14))
                            .foregroundStyle(.grayScale100)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 0.25)
                .foregroundStyle(.grayScale60)
        )
    }
}

// MARK: - Edit Section Bottom Sheet


// MARK: - Extracted subviews (compiler perf)

private extension EditableCanvasView {
    @ViewBuilder
    var mainContent: some View {
        VStack(spacing: 0) {
            // Family member selector capsules (only if user has a family)
            if let family = familyStore.family, !family.otherMembers.isEmpty {
                familyCapsulesRow(members: [family.selfMember] + family.otherMembers)
                    .padding(.top, 22)
                    .padding(.bottom, 16)
                    .padding(.horizontal, 16)
            }
            
            // Selected items scroll view
            if foodNotesStore.isLoadingFoodNotes {
                loadingView
            } else {
                // Always show all sections (even empty) so users can add later.
                let cards = selectedCards()
                cardsScrollView(cards: cards)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            Text("Loading your preferences...")
                .font(ManropeFont.medium.size(16))
                .foregroundStyle(.grayScale100)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("No selections yet")
                .font(ManropeFont.regular.size(16))
                .foregroundStyle(.grayScale100)
            Text("Complete onboarding to see your preferences here")
                .font(ManropeFont.regular.size(14))
                .foregroundStyle(.grayScale130)
            Spacer()
        }
    }
    
    func cardsScrollView(cards: [EditableCanvasCardModel]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        EditableCanvasCard(
                            chips: card.chips,
                            sectionedChips: card.sectionedChips,
                            title: card.title,
                            iconName: card.icon,
                            onEdit: { openEdit(for: card) },
                            itemMemberAssociations: foodNotesStore.itemMemberAssociations ?? [:],
                        showFamilyIcons: familyStore.family?.otherMembers.isEmpty == false,
                        activeMemberId: selectedMemberId
                        )
                        .padding(.top, index == 0 ? 16 : 0)
                        .id(card.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, navCoordinator.isEditSheetPresented ? UIScreen.main.bounds.height * 0.5 : 80)
                .background(scrollTrackingBackground)
            }
            .coordinateSpace(name: "editableCanvasScroll")
            .onAppear {
                scrollToTargetSectionIfNeeded(cards: cards, proxy: proxy)
            }
            .onChange(of: didFinishInitialLoad) { _ in
                scrollToTargetSectionIfNeeded(cards: cards, proxy: proxy)
            }
        }
    }
    
    // MARK: - Family Capsules Row
    @ViewBuilder
    private func familyCapsulesRow(members: [FamilyMember]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(members, id: \.id) { member in
                    let isSelected = selectedMemberId == member.id
                    
                    HStack(spacing: 8) {
                        MemberAvatar.custom(member: member, size: 24, imagePadding: 0)
                        
                        Text(member.name)
                            .font(ManropeFont.medium.size(14))
                            .foregroundStyle(isSelected ? .white : .grayScale150)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 36, alignment: .leading)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color(hex: "#91B640") : Color(hex: "#F8F8F8"))
                    )
                    .onTapGesture {
                        // Toggle selection: tap again to deselect and show all
                        if selectedMemberId == member.id {
                            selectedMemberId = nil
                        } else {
                            selectedMemberId = member.id
                        }
                    }
                }
            }
        }
    }
    
    private func scrollToTargetSectionIfNeeded(cards: [EditableCanvasCardModel], proxy: ScrollViewProxy) {
        guard hasScrolledToTarget == false else { return }
        guard let targetSectionName, targetSectionName.isEmpty == false else { return }
        guard didFinishInitialLoad else { return }
        guard let targetCard = findTargetCard(cards: cards, targetSectionName: targetSectionName) else { return }
        
        // Ensure layout is complete before scrolling.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.45)) {
                let anchorPoint: UnitPoint = shouldCenterLifestyleNutrition ? .top : .center
                proxy.scrollTo(targetCard.id, anchor: anchorPoint)
            }
            hasScrolledToTarget = true
        }
    }
    
    private func findTargetCard(
        cards: [EditableCanvasCardModel],
        targetSectionName: String
    ) -> EditableCanvasCardModel? {
        func norm(_ s: String) -> String {
            s.lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
        }
        
        let target = norm(targetSectionName)
        
        // Primary attempt: exact normalized match
        if let match = cards.first(where: { norm($0.title) == target }) {
            return match
        }
        
        // Secondary fallback: Nutrition
        if let nutrition = cards.first(where: { norm($0.title).contains("nutrition") }) {
            return nutrition
        }
        
        return nil
    }
    
    private func openEdit(for card: EditableCanvasCardModel) {
        if let sectionIndex = store.sections.firstIndex(where: { section in
            section.screens.first?.stepId == card.stepId
        }) {
            navCoordinator.currentEditingSectionIndex = sectionIndex
            store.currentSectionIndex = sectionIndex
        }
        navCoordinator.editingStepId = card.stepId
        navCoordinator.editingMemberId = selectedMemberId  // Pass selected member to edit sheet
        // Ensure cache is loaded for this member so first selection is persisted (currentPreferencesOwnerKey is set)
        foodNotesStore.preparePreferencesForMember(selectedMemberId: selectedMemberId)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            navCoordinator.isEditSheetPresented = true
        }
    }
    
    var scrollTrackingBackground: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    scrollY = geo.frame(in: .named("editableCanvasScroll")).minY
                    prevValue = scrollY
                    maxScrollOffset = scrollY < 0 ? scrollY : 0
                }
                .onChange(of: geo.frame(in: .named("editableCanvasScroll")).minY) { newValue in
                    scrollY = newValue
                    
                    if scrollY < 0 {
                        maxScrollOffset = min(maxScrollOffset, newValue)
                        
                        let scrollDelta = newValue - prevValue
                        let minScrollDelta: CGFloat = 5
                        
                        // Removed headroom collapsing logic to prevent scroll jumps
                        
                        if scrollDelta < -minScrollDelta {
                            isTabBarExpanded = false
                        } else if scrollDelta > minScrollDelta {
                            let bottomThreshold: CGFloat = 100
                            if newValue > (maxScrollOffset + bottomThreshold) {
                                isTabBarExpanded = true
                            }
                        }
                    } else {
                        maxScrollOffset = 0
                    }
                    
                    prevValue = newValue
                }
        }
    }
    
}

#Preview {
    let webService = WebService()
    let onboarding = Onboarding(onboardingFlowtype: .individual)
    let foodNotesStore = FoodNotesStore(webService: webService, onboardingStore: onboarding)

    EditableCanvasView()
        .environmentObject(onboarding)
        .environment(webService)
        .environment(foodNotesStore)
}

