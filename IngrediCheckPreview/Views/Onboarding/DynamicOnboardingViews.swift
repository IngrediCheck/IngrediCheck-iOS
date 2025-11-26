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
    
    @State private var selectedNames: Set<String> = []
    
    var body: some View {
        let headerVariant = (flowType == .individual) ? step.header.individual : step.header.family
        let options = step.content.options ?? []
        
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
    }
    
    private func toggleSelection(for name: String) {
        if selectedNames.contains(name) {
            selectedNames.remove(name)
        } else {
            selectedNames.insert(name)
        }
        syncPreferencesFromSelection()
    }
    
    private func syncPreferencesFromSelection() {
        let values = Array(selectedNames)
        switch step.id {
        case "allergies":
            preferences.allergies = values
        case "intolerances":
            preferences.intolerances = values
        case "healthConditions":
            preferences.healthConditions = values
        case "lifeStage":
            preferences.lifeStage = values
        case "ethical":
            preferences.ethical = values
        case "taste":
            preferences.taste = values
        default:
            break
        }
    }
}

// MARK: - Type 2: Stacked cards with chips (Avoid/LifeStyle/Nutrition-style)

struct DynamicSubStepsQuestionView: View {
    let step: DynamicStep
    let flowType: OnboardingFlowType
    @Binding var preferences: Preferences
    
    /// Card title -> selected option names
    @State private var selections: [String: Set<String>] = [:]
    
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
                    let set = selections[card.title] ?? []
                    return set.contains(chip.name)
                },
                onChipTap: { card, chip in
                    toggleSelection(cardTitle: card.title, chipName: chip.name)
                }
            )
            .padding(.horizontal, 20)
        }
    }
    
    private func toggleSelection(cardTitle: String, chipName: String) {
        var set = selections[cardTitle] ?? []
        if set.contains(chipName) {
            set.remove(chipName)
        } else {
            set.insert(chipName)
        }
        selections[cardTitle] = set
        syncPreferencesFromSelections()
    }
    
    private func syncPreferencesFromSelections() {
        switch step.id {
        case "avoid":
            // Ensure container exists
            if preferences.avoid == nil {
                preferences.avoid = AvoidPreferences(
                    oilsFats: [],
                    animalBased: [],
                    stimulantsSubstances: [],
                    additivesSweeteners: [],
                    plantBasedRestrictions: []
                )
            }
            guard var avoid = preferences.avoid else { return }
            avoid.oilsFats = Array(selections["Oils & Fats"] ?? [])
            avoid.animalBased = Array(selections["Animal-Based"] ?? selections["Animal Based"] ?? [])
            avoid.stimulantsSubstances = Array(selections["Stimulants & Substances"] ?? selections["Stimulants and Substances"] ?? [])
            avoid.additivesSweeteners = Array(selections["Additives & Sweeteners"] ?? selections["Additives and Sweeteners"] ?? [])
            avoid.plantBasedRestrictions = Array(selections["Plant-Based Restrictions"] ?? [])
            preferences.avoid = avoid
            
        case "lifeStyle":
            if preferences.lifestyle == nil {
                preferences.lifestyle = LifestylePreferences(
                    plantBalance: [],
                    qualitySource: [],
                    sustainableLiving: []
                )
            }
            guard var lifestyle = preferences.lifestyle else { return }
            lifestyle.plantBalance = Array(selections["Plant & Balance"] ?? [])
            lifestyle.qualitySource = Array(selections["Quality & Source"] ?? [])
            lifestyle.sustainableLiving = Array(selections["Sustainable Living"] ?? [])
            preferences.lifestyle = lifestyle
            
        case "nutrition":
            if preferences.nutrition == nil {
                preferences.nutrition = NutritionPreferences(
                    macronutrientGoals: [],
                    sugarFiber: [],
                    dietFrameworks: []
                )
            }
            guard var nutrition = preferences.nutrition else { return }
            nutrition.macronutrientGoals = Array(selections["Macronutrient Goals"] ?? [])
            nutrition.sugarFiber = Array(selections["Sugar & Fiber"] ?? [])
            nutrition.dietFrameworks = Array(selections["Diet Frameworks & Patterns"] ?? [])
            preferences.nutrition = nutrition
        default:
            break
        }
    }
}

// MARK: - Type 3: Grouped/expandable regions (Region-style)

struct DynamicRegionsQuestionView: View {
    let step: DynamicStep
    let flowType: OnboardingFlowType
    @Binding var preferences: Preferences
    
    @State private var sections: [SectionedChipModel] = []
    /// Section id -> selected chip titles
    @State private var selections: [String: Set<String>] = [:]
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
                        DynamicRegionSectionRow(
                            section: section,
                            isSectionSelected: !(selections[section.id] ?? []).isEmpty,
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
                                (selections[section.id] ?? []).contains(chip.name)
                            },
                            onChipTap: { chip in
                                toggleSelection(sectionId: section.id, chipName: chip.name)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .frame(height: UIScreen.main.bounds.height * 0.3)
        }
    }
    
    private func toggleSelection(sectionId: String, chipName: String) {
        var set = selections[sectionId] ?? []
        if set.contains(chipName) {
            set.remove(chipName)
        } else {
            set.insert(chipName)
        }
        selections[sectionId] = set
        syncPreferencesFromSelections()
    }
    
    private func syncPreferencesFromSelections() {
        if preferences.region == nil {
            preferences.region = RegionPreferences(
                indiaSouthAsia: [],
                africa: [],
                eastAsian: [],
                middleEastMediterranean: [],
                westernNative: [],
                seventhDayAdventist: [],
                other: []
            )
        }
        guard var region = preferences.region else { return }
        
        // Helper to fetch selected names for a section title
        func names(forTitle title: String) -> [String] {
            guard let section = sections.first(where: { $0.title == title }) else { return [] }
            let set = selections[section.id] ?? []
            return Array(set)
        }
        
        region.indiaSouthAsia = names(forTitle: "India & South Asia")
        region.africa = names(forTitle: "Africa")
        region.eastAsian = names(forTitle: "East Asia") + names(forTitle: "East Asian")
        region.middleEastMediterranean = names(forTitle: "Middle East & Mediterranean") + names(forTitle: "Middle East and Mediterranean")
        region.westernNative = names(forTitle: "Western / Native traditions")
        region.seventhDayAdventist = names(forTitle: "Seventh-day Adventist")
        region.other = names(forTitle: "Other")
        
        preferences.region = region
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
                                    colors: [Color(hex: "1B9300"), Color(hex: "00961D")],
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


