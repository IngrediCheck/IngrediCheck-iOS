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
        switch step.id {
        case "allergies":
            return preferences.allergies ?? []
        case "intolerances":
            return preferences.intolerances ?? []
        case "healthConditions":
            return preferences.healthConditions ?? []
        case "lifeStage":
            return preferences.lifeStage ?? []
        case "ethical":
            return preferences.ethical ?? []
        case "taste":
            return preferences.taste ?? []
        default:
            return []
        }
    }
    
    private func setValues(_ values: [String]) {
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
        switch step.id {
        case "avoid":
            return avoidSelections(for: cardTitle)
        case "lifeStyle":
            return lifestyleSelections(for: cardTitle)
        case "nutrition":
            return nutritionSelections(for: cardTitle)
        default:
            return []
        }
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
    
    private func avoidSelections(for cardTitle: String) -> Set<String> {
        guard let avoid = preferences.avoid else { return [] }
        switch cardTitle {
        case "Oils & Fats":
            return Set(avoid.oilsFats)
        case "Animal-Based", "Animal Based":
            return Set(avoid.animalBased)
        case "Stimulants & Substances", "Stimulants and Substances":
            return Set(avoid.stimulantsSubstances)
        case "Additives & Sweeteners", "Additives and Sweeteners":
            return Set(avoid.additivesSweeteners)
        case "Plant-Based Restrictions":
            return Set(avoid.plantBasedRestrictions)
        default:
            return []
        }
    }
    
    private func lifestyleSelections(for cardTitle: String) -> Set<String> {
        guard let lifestyle = preferences.lifestyle else { return [] }
        switch cardTitle {
        case "Plant & Balance":
            return Set(lifestyle.plantBalance)
        case "Quality & Source":
            return Set(lifestyle.qualitySource)
        case "Sustainable Living":
            return Set(lifestyle.sustainableLiving)
        default:
            return []
        }
    }
    
    private func nutritionSelections(for cardTitle: String) -> Set<String> {
        guard let nutrition = preferences.nutrition else { return [] }
        switch cardTitle {
        case "Macronutrient Goals":
            return Set(nutrition.macronutrientGoals)
        case "Sugar & Fiber":
            return Set(nutrition.sugarFiber)
        case "Diet Frameworks & Patterns":
            return Set(nutrition.dietFrameworks)
        default:
            return []
        }
    }
    
    private func syncPreferences(from set: Set<String>, for cardTitle: String) {
        switch step.id {
        case "avoid":
            syncAvoidPreferences(from: set, for: cardTitle)
        case "lifeStyle":
            syncLifestylePreferences(from: set, for: cardTitle)
        case "nutrition":
            syncNutritionPreferences(from: set, for: cardTitle)
        default:
            break
        }
    }
    
    private func syncAvoidPreferences(from set: Set<String>, for cardTitle: String) {
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
        switch cardTitle {
        case "Oils & Fats":
            avoid.oilsFats = Array(set)
        case "Animal-Based", "Animal Based":
            avoid.animalBased = Array(set)
        case "Stimulants & Substances", "Stimulants and Substances":
            avoid.stimulantsSubstances = Array(set)
        case "Additives & Sweeteners", "Additives and Sweeteners":
            avoid.additivesSweeteners = Array(set)
        case "Plant-Based Restrictions":
            avoid.plantBasedRestrictions = Array(set)
        default:
            break
        }
        preferences.avoid = avoid
    }
    
    private func syncLifestylePreferences(from set: Set<String>, for cardTitle: String) {
        if preferences.lifestyle == nil {
            preferences.lifestyle = LifestylePreferences(
                plantBalance: [],
                qualitySource: [],
                sustainableLiving: []
            )
        }
        guard var lifestyle = preferences.lifestyle else { return }
        switch cardTitle {
        case "Plant & Balance":
            lifestyle.plantBalance = Array(set)
        case "Quality & Source":
            lifestyle.qualitySource = Array(set)
        case "Sustainable Living":
            lifestyle.sustainableLiving = Array(set)
        default:
            break
        }
        preferences.lifestyle = lifestyle
    }
    
    private func syncNutritionPreferences(from set: Set<String>, for cardTitle: String) {
        if preferences.nutrition == nil {
            preferences.nutrition = NutritionPreferences(
                macronutrientGoals: [],
                sugarFiber: [],
                dietFrameworks: []
            )
        }
        guard var nutrition = preferences.nutrition else { return }
        switch cardTitle {
        case "Macronutrient Goals":
            nutrition.macronutrientGoals = Array(set)
        case "Sugar & Fiber":
            nutrition.sugarFiber = Array(set)
        case "Diet Frameworks & Patterns":
            nutrition.dietFrameworks = Array(set)
        default:
            break
        }
        preferences.nutrition = nutrition
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
        guard let region = preferences.region else { return [] }
        switch sectionTitle {
        case "India & South Asia":
            return Set(region.indiaSouthAsia)
        case "Africa":
            return Set(region.africa)
        case "East Asia", "East Asian":
            return Set(region.eastAsian)
        case "Middle East & Mediterranean", "Middle East and Mediterranean":
            return Set(region.middleEastMediterranean)
        case "Western / Native traditions":
            return Set(region.westernNative)
        case "Seventh-day Adventist":
            return Set(region.seventhDayAdventist)
        case "Other":
            return Set(region.other)
        default:
            return []
        }
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
        switch sectionTitle {
        case "India & South Asia":
            region.indiaSouthAsia = Array(set)
        case "Africa":
            region.africa = Array(set)
        case "East Asia", "East Asian":
            region.eastAsian = Array(set)
        case "Middle East & Mediterranean", "Middle East and Mediterranean":
            region.middleEastMediterranean = Array(set)
        case "Western / Native traditions":
            region.westernNative = Array(set)
        case "Seventh-day Adventist":
            region.seventhDayAdventist = Array(set)
        case "Other":
            region.other = Array(set)
        default:
            break
        }
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


