//
//  DynamicOnboardingViews.swift
//  IngrediCheckPreview
//
//  Created to render dynamic onboarding JSON in three reusable shapes:
//  - type-1: simple chip lists (Allergies-style)
//  - type-2: stacked cards with chips (Avoid/LifeStyle/Nutrition-style)
//  - type-3: grouped/expandable regions (Region-style)
//

import SwiftUI

// MARK: - Type 1: Simple options list (Allergies-style)

struct DynamicOptionsQuestionView: View {
    let step: DynamicStep
    let flowType: OnboardingFlowType
    @Binding var preferences: Preferences
    
    var body: some View {
        let headerVariant = (flowType == .individual) ? step.header.individual : step.header.family
        let options = step.content.options ?? []
        let selectedNames = currentSelections()
        
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                onboardingSheetTitle(title: headerVariant.question)
                if let description = headerVariant.description {
                    onboardingSheetSubtitle(subtitle: description, onboardingFlowType: flowType)
                }
            }
            .padding(.horizontal, 20)
            
            if flowType == .family {
                VStack(alignment: .leading, spacing: 8) {
                    FamilyCarouselView()
                    onboardingSheetFamilyMemberSelectNote()
                }
                .padding(.leading, 20)
            }
            
            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(options) { option in
                    IngredientsChips(
                        title: option.name,
                        image: option.icon,
                        onClick: { toggleSelection(for: option.name) },
                        isSelected: selectedNames.contains(option.name)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .id(step.id)
    }
    
    private func currentSelections() -> Set<String> {
        Set(valuesForCurrentStep())
    }
    
    private func valuesForCurrentStep() -> [String] {
        let sectionName = step.header.name
        guard let value = preferences.sections[sectionName],
              case .list(let items) = value else {
            return []
        }
        return items
    }
    
    private func setValues(_ values: [String]) {
        let sectionName = step.header.name
        preferences.sections[sectionName] = .list(values)
    }
    
    private func toggleSelection(for name: String) {
        var values = valuesForCurrentStep()
        if let index = values.firstIndex(of: name) {
            values.remove(at: index)
        } else {
            values.append(name)
        }
        setValues(values)
    }
}

// MARK: - Type 2: Stacked cards with chips (Avoid/LifeStyle/Nutrition-style)

struct DynamicSubStepsQuestionView: View {
    let step: DynamicStep
    let flowType: OnboardingFlowType
    @Binding var preferences: Preferences
    
    var body: some View {
        let headerVariant = (flowType == .individual) ? step.header.individual : step.header.family
        let subSteps = step.content.subSteps ?? []
        
        // Map dynamic sub-steps into existing `Card` model used by `StackedCards`
        let cards: [Card] = subSteps.map { subStep in
            let chipModels = (subStep.options ?? []).map { ChipsModel(name: $0.name, icon: $0.icon) }
            let color: Color
            if let hex = subStep.colorHex {
                color = Color(hex: hex)
            } else {
                color = .avatarYellow
            }
            return Card(
                title: subStep.title,
                subTitle: subStep.description,
                color: color,
                chips: chipModels
            )
        }
        
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                onboardingSheetTitle(title: headerVariant.question)
                if let description = headerVariant.description {
                    onboardingSheetSubtitle(subtitle: description, onboardingFlowType: flowType)
                }
            }
            .padding(.horizontal, 20)
            
            if flowType == .family {
                VStack(alignment: .leading, spacing: 8) {
                    FamilyCarouselView()
                    onboardingSheetFamilyMemberSelectNote()
                }
                .padding(.leading, 20)
            }
            
            StackedCards(
                cards: cards,
                isChipSelected: { card, chip in
                    selections(for: card.title).contains(chip.name)
                },
                onChipTap: { card, chip in
                    toggleSelection(cardTitle: card.title, chipName: chip.name)
                }
            )
            .padding(.horizontal, 20)
        }
        .id(step.id)
    }
    
    private func selections(for cardTitle: String) -> Set<String> {
        let sectionName = step.header.name
        guard let value = preferences.sections[sectionName],
              case .nested(let nestedDict) = value,
              let items = nestedDict[cardTitle] else {
            return []
        }
        return Set(items)
    }
    
    private func toggleSelection(cardTitle: String, chipName: String) {
        var set = selections(for: cardTitle)
        if set.contains(chipName) {
            set.remove(chipName)
        } else {
            set.insert(chipName)
        }
        syncPreferences(from: set, for: cardTitle)
    }
    
    private func syncPreferences(from set: Set<String>, for cardTitle: String) {
        let sectionName = step.header.name
        var nestedDict: [String: [String]]
        
        // Get existing nested dict or create new one
        if let existingValue = preferences.sections[sectionName],
           case .nested(let existingDict) = existingValue {
            nestedDict = existingDict
        } else {
            nestedDict = [:]
        }
        
        // Update the specific card's selections
        nestedDict[cardTitle] = Array(set)
        
        // Save back to preferences
        preferences.sections[sectionName] = .nested(nestedDict)
    }
}

// MARK: - Type 3: Grouped/expandable regions (Region-style)

struct DynamicRegionsQuestionView: View {
    let step: DynamicStep
    let flowType: OnboardingFlowType
    @Binding var preferences: Preferences
    
    @State private var sections: [SectionedChipModel] = []
    @State private var expandedSectionIds: Set<String> = []
    
    init(step: DynamicStep, flowType: OnboardingFlowType, preferences: Binding<Preferences>) {
        self.step = step
        self.flowType = flowType
        self._preferences = preferences
        
        let initialSections: [SectionedChipModel] = (step.content.regions ?? []).map { region in
            SectionedChipModel(
                title: region.name,
                subtitle: nil,
                chips: region.subRegions.map { ChipsModel(name: $0.name, icon: $0.icon) }
            )
        }
        _sections = State(initialValue: initialSections)
        _expandedSectionIds = State(initialValue: [])
    }
    
    var body: some View {
        let headerVariant = (flowType == .individual) ? step.header.individual : step.header.family
        
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                onboardingSheetTitle(title: headerVariant.question)
                if let description = headerVariant.description {
                    onboardingSheetSubtitle(subtitle: description, onboardingFlowType: flowType)
                }
            }
            .padding(.horizontal, 20)
            
            if flowType == .family {
                VStack(alignment: .leading, spacing: 8) {
                    FamilyCarouselView()
                    onboardingSheetFamilyMemberSelectNote()
                }
                .padding(.leading, 20)
            }
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sections) { section in
                        // If a region only has a single sub-region, skip the expandable
                        // header and surface the chip directly – a dropdown for a single
                        // option doesn’t add any value.
                        let selectedSet = selections(for: section.title)
                        if section.chips.count == 1, let chip = section.chips.first {
                            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                                IngredientsChips(
                                    title: chip.name,
                                    image: chip.icon,
                                    onClick: {
                                        toggleSelection(sectionTitle: section.title, chipName: chip.name)
                                    },
                                    isSelected: selectedSet.contains(chip.name)
                                )
                            }
                            .padding(.vertical, 4)
                        } else {
                            DynamicRegionSectionRow(
                                section: section,
                                isSectionSelected: !selectedSet.isEmpty,
                                isExpanded: expandedSectionIds.contains(section.id),
                                onToggleExpanded: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        if expandedSectionIds.contains(section.id) {
                                            expandedSectionIds.remove(section.id)
                                        } else {
                                            expandedSectionIds.insert(section.id)
                                        }
                                    }
                                },
                                isChipSelected: { chip in
                                    selections(for: section.title).contains(chip.name)
                                },
                                onChipTap: { chip in
                                    toggleSelection(sectionTitle: section.title, chipName: chip.name)
                                }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .frame(height: UIScreen.main.bounds.height * 0.3)
        }
        .id(step.id)
    }
    
    private func selections(for sectionTitle: String) -> Set<String> {
        let stepSectionName = step.header.name
        guard let value = preferences.sections[stepSectionName],
              case .nested(let nestedDict) = value,
              let items = nestedDict[sectionTitle] else {
            return []
        }
        return Set(items)
    }
    
    private func toggleSelection(sectionTitle: String, chipName: String) {
        var set = selections(for: sectionTitle)
        if set.contains(chipName) {
            set.remove(chipName)
        } else {
            set.insert(chipName)
        }
        syncRegionPreferences(from: set, for: sectionTitle)
    }
    
    private func syncRegionPreferences(from set: Set<String>, for sectionTitle: String) {
        let stepSectionName = step.header.name
        var nestedDict: [String: [String]]
        
        // Get existing nested dict or create new one
        if let existingValue = preferences.sections[stepSectionName],
           case .nested(let existingDict) = existingValue {
            nestedDict = existingDict
        } else {
            nestedDict = [:]
        }
        
        // Update the specific region's selections
        nestedDict[sectionTitle] = Array(set)
        
        // Save back to preferences
        preferences.sections[stepSectionName] = .nested(nestedDict)
    }
}

private struct DynamicRegionSectionRow: View {
    let section: SectionedChipModel
    let isSectionSelected: Bool
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let isChipSelected: (ChipsModel) -> Bool
    let onChipTap: (ChipsModel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                onToggleExpanded()
            } label: {
                HStack(spacing: 40) {
                    Text(section.title)
                        .font(ManropeFont.medium.size(14))
                        .foregroundStyle(isSectionSelected ? .primary100 : .grayScale150)
                    
                    Circle()
                        .fill(isSectionSelected ? .grayScale60 : .grayScale30)
                        .foregroundStyle(isSectionSelected ? .grayScale100 : .grayScale60)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "chevron.up")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.grayScale100)
                                .rotationEffect(isExpanded ? .degrees(0) : .degrees(180))
                        )
                }
                .padding(.vertical, 6)
                .padding(.leading, 16)
                .padding(.trailing, 4)
                .background {
                    if isSectionSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    } else {
                        Capsule()
                            .fill(.grayScale10)
                    }
                }
                .overlay(
                    Capsule()
                        .stroke(lineWidth: isSectionSelected ? 0 : 1)
                        .foregroundStyle(.grayScale60)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(section.chips) { chip in
                        IngredientsChips(
                            title: chip.name,
                            image: chip.icon,
                            onClick: {
                                onChipTap(chip)
                            },
                            isSelected: isChipSelected(chip)
                        )
                    }
                }
                .transition(.blurReplace)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Container that picks the right dynamic view for a step

struct DynamicOnboardingStepView: View {
    let step: DynamicStep
    let flowType: OnboardingFlowType
    @Binding var preferences: Preferences
    
    var body: some View {
        switch step.type {
        case .type1:
            DynamicOptionsQuestionView(step: step, flowType: flowType, preferences: $preferences)
        case .type2:
            DynamicSubStepsQuestionView(step: step, flowType: flowType, preferences: $preferences)
        case .type3:
            DynamicRegionsQuestionView(step: step, flowType: flowType, preferences: $preferences)
        case .unknown:
            // Fallback simple view – safe default for unexpected types.
            VStack(spacing: 12) {
                Text(step.header.name)
                    .font(NunitoFont.bold.size(18))
                    .foregroundStyle(.grayScale150)
                Text("Unsupported step type in current build.")
                    .font(ManropeFont.regular.size(14))
                    .foregroundStyle(.grayScale100)
            }
            .padding(20)
        }
    }
}

#Preview("Dynamic type-1 example") {
    let steps = DynamicStepsProvider.loadSteps()
    let step = steps.first { $0.type == .type1 } ?? steps.first!
    return DynamicOnboardingStepView(step: step, flowType: .individual, preferences: .constant(Preferences()))
}


