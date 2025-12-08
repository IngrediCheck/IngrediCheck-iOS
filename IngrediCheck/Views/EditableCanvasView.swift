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
    
    @State private var editingStepId: String? = nil
    @State private var isEditSheetPresented: Bool = false
    @State private var tagBarScrollTarget: UUID? = nil
    @State private var currentEditingSectionIndex: Int = 0
    @State private var isProgrammaticChange: Bool = false
    
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
                        currentBottomSheetRoute: nil
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
                    if let cards = cards, !cards.isEmpty {
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
                                        }
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
                        onNext: {
                            handleNextSection()
                        }
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
    }
    
    private func icon(for stepId: String) -> String {
        if let step = store.step(for: stepId),
           let icon = step.header.iconURL,
           icon.isEmpty == false {
            return icon
        }
        return "allergies"
    }
    
    private func chips(for stepId: String) -> [ChipsModel]? {
        guard let step = store.step(for: stepId) else { return nil }
        let sectionName = step.header.name
        
        guard let value = store.preferences.sections[sectionName],
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
        
        guard let value = store.preferences.sections[sectionName],
              case .nested(let nestedDict) = value else {
            return nil
        }
        
        guard let subSteps = step.content.subSteps else { return nil }
        
        // Convert nested dict to sectioned chips with icons
        var sections: [SectionedChipModel] = []
        
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
    
    private func handleNextSection() {
        // Move to next section
        if currentEditingSectionIndex < store.sections.count - 1 {
            let nextIndex = currentEditingSectionIndex + 1
            if let nextStepId = store.sections[nextIndex].screens.first?.stepId {
                isProgrammaticChange = true
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentEditingSectionIndex = nextIndex
                    store.currentSectionIndex = nextIndex
                    editingStepId = nextStepId
                }
                // Sheet will update automatically via editingStepId change
            }
        } else {
            // Last section, close the sheet
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditSheetPresented = false
            }
        }
    }
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
    var chips: [ChipsModel]? = nil
    var sectionedChips: [SectionedChipModel]? = nil
    var title: String = "Allergies"
    var iconName: String = "allergies"
    var onEdit: (() -> Void)? = nil
    
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
    @Binding var isPresented: Bool
    
    let stepId: String
    let currentSectionIndex: Int
    var onNext: (() -> Void)? = nil
    
    private var isLastSection: Bool {
        currentSectionIndex >= store.sections.count - 1
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let step = store.step(for: stepId) {
                DynamicOnboardingStepView(
                    step: step,
                    flowType: store.onboardingFlowtype,
                    preferences: $store.preferences
                )
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .transition(.opacity)
            }
            
            // Next button (GreenCircle)
            if let onNext = onNext {
                Button(action: onNext) {
                    GreenCircle()
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Color.white)
        .cornerRadius(36, corners: [.topLeft, .topRight])
        .shadow(radius: 27.5)
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut(duration: 0.2), value: stepId)
    }
}

#Preview {
    EditableCanvasView()
        .environmentObject(Onboarding(onboardingFlowtype: .individual))
}

