//
//  EditableCanvasView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar on 15/11/25.
//

import SwiftUI

struct EditableCanvasView: View {
    @EnvironmentObject private var store: Onboarding
    @Environment(\.dismiss) private var dismiss
    @Environment(WebService.self) private var webService
    @Environment(FamilyStore.self) private var familyStore
    
    @State private var foodNotesStore: FoodNotesStore?
    
    @State private var editingStepId: String? = nil
    @State private var isEditSheetPresented: Bool = false
    @State private var tagBarScrollTarget: UUID? = nil
    @State private var currentEditingSectionIndex: Int = 0
    @State private var isProgrammaticChange: Bool = false
    @State private var debounceTask: Task<Void, Never>? = nil
    @State private var isLoadingMemberPreferences: Bool = false
    
    var body: some View {
        let cards = selectedCards()
        
        NavigationView {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // CanvasTagBar
                    CanvasTagBar(
                        store: store,
                        onTapCurrentSection: {
                            // Open edit sheet for current section when tapped
                            openEditSheetForCurrentSection()
                        },
                        scrollTarget: $tagBarScrollTarget,
                        currentBottomSheetRoute: nil,
                        allowTappingIncompleteSections: true, // Allow tapping any section in edit mode
                        forceDarkGreen: true
                    )
                    .onChange(of: store.currentSectionIndex) { newIndex in
                        // When section changes via tag bar tap, update/edit sheet for that section
                        if !isProgrammaticChange {
                            // Always update the sheet to show the tapped section's content
                            openEditSheetForSection(at: newIndex)
                        }
                        isProgrammaticChange = false
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 16)
                    
                    // Selected items scroll view
                    if foodNotesStore?.isLoadingFoodNotes == true {
                        // Loading state
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
                    } else if let cards = cards, !cards.isEmpty {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 16) {
                                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    EditableCanvasCard(
                        chips: card.chips,
                        sectionedChips: card.sectionedChips,
                        title: card.title,
                        iconName: card.icon,
                        onEdit: {
                            // Find the section index for this card
                            if let sectionIndex = store.sections.firstIndex(where: { section in
                                section.screens.first?.stepId == card.stepId
                            }) {
                                currentEditingSectionIndex = sectionIndex
                                store.currentSectionIndex = sectionIndex
                            }
                            editingStepId = card.stepId
                            isEditSheetPresented = true
                        },
                        itemMemberAssociations: foodNotesStore?.itemMemberAssociations ?? [:],
                        showFamilyIcons: familyStore.family?.otherMembers.isEmpty == false
                    )
                                    .padding(.top, index == 0 ? 16 : 0)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, isEditSheetPresented ? UIScreen.main.bounds.height * 0.5 : 80)
                        }
                    } else {
                        // Empty state
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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                // Custom bottom sheet overlay (similar to PersistentBottomSheet)
                if isEditSheetPresented, let stepId = editingStepId {
                    EditSectionBottomSheet(
                        isPresented: $isEditSheetPresented,
                        stepId: stepId,
                        currentSectionIndex: currentEditingSectionIndex,
                        foodNotesStore: foodNotesStore
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .edgesIgnoringSafeArea(.bottom)
            .navigationBarTitleDisplayMode(.inline)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.neutral500)
                    .frame(width: 60, height: 4)
                    .padding(.top, 12)
                , alignment: .top
            )
        }
        .onAppear {
            // Initialize FoodNotesStore with environment values
            if foodNotesStore == nil {
                foodNotesStore = FoodNotesStore(webService: webService, onboardingStore: store)
            }
            
            // Update completion status for all sections based on their data
            store.updateSectionCompletionStatus()
            
            // Fetch and load food notes data when view appears
            Task {
                await foodNotesStore?.loadFoodNotesAll()
                
                // Load preferences for the current selection (member or family)
                // so they are ready when the edit sheet opens.
                isLoadingMemberPreferences = true
                if let memberId = familyStore.selectedMemberId?.uuidString.lowercased() {
                    print("[EditableCanvasView] onAppear: Loading preferences for selected member \(memberId)")
                    await foodNotesStore?.loadFoodNotesForMember(memberId: memberId)
                } else {
                    print("[EditableCanvasView] onAppear: Loading preferences for family (Everyone)")
                    await foodNotesStore?.loadFoodNotesForFamily()
                }
                isLoadingMemberPreferences = false
            }
        }
        .onDisappear {
            // Cancel any pending debounce task when view disappears
            debounceTask?.cancel()
            debounceTask = nil
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
            
            // Debounce API call - cancel previous task and start new one
            debounceTask?.cancel()
            debounceTask = Task {
                do {
                    // Wait 5 seconds
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    
                    // Check if task was cancelled
                    try Task.checkCancellation()
                    
                    // Build content structure and call API for the currently visible section only
                    let changedSectionName = store.currentSection.name
                    let changedSections: Set<String> = [changedSectionName]
                    await foodNotesStore?.updateFoodNotes(
                        selectedMemberId: familyStore.selectedMemberId,
                        changedSections: changedSections
                    )
                } catch {
                    // Task was cancelled or sleep interrupted - ignore
                    if !(error is CancellationError) {
                        print("[EditableCanvasView] Debounce task error: \(error)")
                    }
                }
            }
        }
        .onChange(of: familyStore.selectedMemberId) { newValue in
            // When switching members, mark that we are loading and trigger the load.
            print("[EditableCanvasView] Member switched to \(newValue?.uuidString ?? "Everyone"), loading preferences")
            isLoadingMemberPreferences = true
            Task {
                if let memberId = newValue?.uuidString.lowercased() {
                    await foodNotesStore?.loadFoodNotesForMember(memberId: memberId)
                } else {
                    await foodNotesStore?.loadFoodNotesForFamily()
                }
                isLoadingMemberPreferences = false
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
        guard let foodNotesStore = foodNotesStore,
              let memberIds = foodNotesStore.itemMemberAssociations[sectionName]?[itemName] else {
            return []
        }
        
        // Return member IDs directly (already UUID strings or "Everyone")
        // ChipMemberAvatarView will resolve these to FamilyMember objects
        return memberIds
    }
    
    private func chips(for stepId: String) -> [ChipsModel]? {
        guard let step = store.step(for: stepId) else { return nil }
        let sectionName = step.header.name
        
        // Use canvasPreferences so scroll cards always show the union view
        // (Everyone + all members) and do not change when switching member.
        guard let foodNotesStore = foodNotesStore,
              let value = foodNotesStore.canvasPreferences.sections[sectionName],
              case .list(let items) = value else {
            return nil
        }
        
        // Get icons from step options
        let options = step.content.options ?? []
        return items.compactMap { itemName -> ChipsModel? in
            if let option = options.first(where: { $0.name == itemName }) {
                return ChipsModel(name: option.name, icon: option.icon)
            }
            return ChipsModel(name: itemName, icon: nil)
        }
    }
    
    private func sectionedChips(for stepId: String) -> [SectionedChipModel]? {
        guard let step = store.step(for: stepId) else { return nil }
        let sectionName = step.header.name
        
        // Use canvasPreferences for union view
        guard let foodNotesStore = foodNotesStore,
              let value = foodNotesStore.canvasPreferences.sections[sectionName],
              case .nested(let nestedDict) = value else {
            return nil
        }
        
        // Type-2 steps use subSteps, type-3 steps use regions. Handle both.
        var sections: [SectionedChipModel] = []
        
        if let subSteps = step.content.subSteps {
            // MARK: Type-2 (Avoid / Lifestyle / Nutrition-style)
            for subStep in subSteps {
                guard let selectedItems = nestedDict[subStep.title],
                      !selectedItems.isEmpty else {
                    continue
                }
                
                // Map selected items to ChipsModel with icons
                let selectedChips: [ChipsModel] = selectedItems.compactMap { itemName in
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
                
                let selectedChips: [ChipsModel] = selectedItems.compactMap { itemName in
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
    
    private func selectedCards() -> [EditableCanvasCardModel]? {
        var cards: [EditableCanvasCardModel] = []
        
        for section in store.sections {
            guard let stepId = section.screens.first?.stepId else { continue }
            let chips = chips(for: stepId)
            let groupedChips = sectionedChips(for: stepId)
            
            if chips != nil || groupedChips != nil {
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
        }
        
        return cards.isEmpty ? nil : cards
    }
    
    private func openEditSheetForCurrentSection() {
        if let stepId = store.currentSection.screens.first?.stepId {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentEditingSectionIndex = store.currentSectionIndex
                editingStepId = stepId
                isEditSheetPresented = true
            }
        }
    }
    
    private func openEditSheetForSection(at index: Int) {
        guard store.sections.indices.contains(index),
              let stepId = store.sections[index].screens.first?.stepId else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            currentEditingSectionIndex = index
            editingStepId = stepId
            isEditSheetPresented = true
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
    
    // Helper function to get member identifiers for an item
    // Returns "Everyone" or member UUID strings for use in ChipMemberAvatarView
    private func getMemberIdentifiers(for sectionName: String, itemName: String) -> [String] {
        guard let memberIds = itemMemberAssociations[sectionName]?[itemName] else {
            return []
        }
        
        // Return member IDs directly (already UUID strings or "Everyone")
        // ChipMemberAvatarView will resolve these to FamilyMember objects
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
                                .frame(width: 14, height: 14)
                                
                            Text("Edit")
                                .font(NunitoFont.medium.size(14))
                                .foregroundStyle(.grayScale130)
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
                if let sectionedChips = sectionedChips {
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
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.white)
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 0.25)
                .foregroundStyle(.grayScale60)
        )
    }
}

// MARK: - Edit Section Bottom Sheet

struct EditSectionBottomSheet: View {
    @EnvironmentObject private var store: Onboarding
    @Environment(FamilyStore.self) private var familyStore
    @Binding var isPresented: Bool
    
    let stepId: String
    let currentSectionIndex: Int
    let foodNotesStore: FoodNotesStore?
    
    // Determine flow type: use .family if user has a family, otherwise use store's flow type
    private var effectiveFlowType: OnboardingFlowType {
        // If there are other members in the family, show the family selection carousel
        if let family = familyStore.family, !family.otherMembers.isEmpty {
            return .family
        }
        // Otherwise treat as an individual flow (hides carousel)
        return .individual
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let step = store.step(for: stepId) {
                DynamicOnboardingStepView(
                    step: step,
                    flowType: effectiveFlowType,
                    preferences: $store.preferences
                )
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.top, 24)
                .padding(.bottom, 100) // Increased padding to accommodate Done button
                .transition(.opacity)
            }
            
            // Done button (GreenCapsule) - closes the sheet
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPresented = false
                }
            }) {
                GreenCapsule(
                    title: "Done",
                    takeFullWidth: false,
                    isLoading: foodNotesStore?.isLoadingFoodNotes ?? false
                )
            }
            .buttonStyle(.plain)
            .disabled(foodNotesStore?.isLoadingFoodNotes ?? false)
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Color.white)
        .cornerRadius(36, corners: [.topLeft, .topRight])
        .shadow(radius: 27.5)
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut(duration: 0.2), value: stepId)
        .onChange(of: stepId) { _ in
            // Update completion status when switching sections
            store.updateSectionCompletionStatus()
        }
        .onChange(of: isPresented) { newValue in
            // Update completion status when sheet is dismissed
            if !newValue {
                store.updateSectionCompletionStatus()
            }
        }
    }
}

#Preview {
    EditableCanvasView()
        .environmentObject(Onboarding(onboardingFlowtype: .individual))
}

