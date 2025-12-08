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
    
    var body: some View {
        let cards = selectedCards()
        
        NavigationView {
            VStack(spacing: 0) {
                // CanvasTagBar
                CanvasTagBar(
                    store: store,
                    onTapCurrentSection: {
                        // No-op for single section view
                    },
                    scrollTarget: $tagBarScrollTarget,
                    currentBottomSheetRoute: nil
                )
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
                                        editingStepId = card.stepId
                                        isEditSheetPresented = true
                                    }
                                )
                                .padding(.top, index == 0 ? 16 : 0)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 80)
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
            .navigationBarTitleDisplayMode(.inline)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.neutral500)
                    .frame(width: 60, height: 4)
                    .padding(.top, 12)
                , alignment: .top
            )
        }
        .sheet(isPresented: $isEditSheetPresented) {
            if let stepId = editingStepId {
                EditSectionSheet(
                    isPresented: $isEditSheetPresented, stepId: stepId
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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

// MARK: - Edit Section Sheet

struct EditSectionSheet: View {
    @EnvironmentObject private var store: Onboarding
    @Binding var isPresented: Bool
    
    let stepId: String
    
    var body: some View {
        if let step = store.step(for: stepId) {
            DynamicOnboardingStepView(
                step: step,
                flowType: store.onboardingFlowtype,
                preferences: $store.preferences
            )
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    EditableCanvasView()
        .environmentObject(Onboarding(onboardingFlowtype: .individual))
}

