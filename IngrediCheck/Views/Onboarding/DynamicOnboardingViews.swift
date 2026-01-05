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
            // Don't show carousel for singleMember flow (adding specific member from home)
            
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
        let lowerName = name.lowercased()
        let isExclusive = (lowerName == "other" || lowerName == "none of these apply")
        
        if isExclusive {
            // If Exclusive option is selected:
            // 1. Clear everything else
            // 2. Toggle itself (if already selected, remove it; if not, set it as the only item)
            if values.contains(name) {
                values.removeAll { $0 == name }
            } else {
                values = [name]
            }
        } else {
            // Normal option selected
            // 1. Remove any exclusive options ("Other", "None of these apply")
            values.removeAll { $0.lowercased() == "other" || $0.lowercased() == "none of these apply" }
            
            // 2. Toggle the selected option
            if let index = values.firstIndex(of: name) {
                values.remove(at: index)
            } else {
                values.append(name)
            }
        }
        
        setValues(values)
    }
}

// MARK: - Type 2: Stacked cards with chips (Avoid/LifeStyle/Nutrition-style)

struct DynamicSubStepsQuestionView: View {
    let step: DynamicStep
    let flowType: OnboardingFlowType
    @Binding var preferences: Preferences
    @Environment(UserPreferences.self) var userPreferences
    
    @State private var showTutorial: Bool = false
    @State private var cardFrame: CGRect = .zero
    @State private var isAnimatingHand: Bool = false
    
    var body: some View {
        let headerVariant = (flowType == .individual) ? step.header.individual : step.header.family
        let subSteps = step.content.subSteps ?? []
        
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
        
        ZStack {
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
                    },
                    onSwipe: {
                        if showTutorial {
                            withAnimation {
                                showTutorial = false
                                userPreferences.cardsSwipeTutorialShown = true
                            }
                        }
                    }
                )
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                cardFrame = geo.frame(in: .global)
                            }
                            .onChange(of: geo.frame(in: .global)) {
                                cardFrame = $0
                            }
                    }
                )
                .padding(.horizontal, 20)
            }
            .preference(
                key: TutorialOverlayPreferenceKey.self,
                value: TutorialData(show: showTutorial, cardFrame: cardFrame)
            )
        }
        .id(step.id)
        .onAppear {
            if step.id == "avoid" && !userPreferences.cardsSwipeTutorialShown {
                // Determine if we should show tutorial
                // Wait slightly for layout to settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        showTutorial = true
                    }
                }
            }
        }
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
        let lowerName = chipName.lowercased()
        let isExclusive = (lowerName == "other" || lowerName == "none of these apply")
        
        if isExclusive {
            if set.contains(chipName) {
                set.remove(chipName)
            } else {
                set = [chipName]
            }
        } else {
            let exclusives = set.filter { $0.lowercased() == "other" || $0.lowercased() == "none of these apply" }
            for exclusive in exclusives {
                set.remove(exclusive)
            }
            
            if set.contains(chipName) {
                set.remove(chipName)
            } else {
                set.insert(chipName)
            }
        }
        
        syncPreferences(from: set, for: cardTitle)
    }
    
    private func syncPreferences(from set: Set<String>, for cardTitle: String) {
        let sectionName = step.header.name
        var nestedDict: [String: [String]]
        
        if let existingValue = preferences.sections[sectionName],
           case .nested(let existingDict) = existingValue {
            nestedDict = existingDict
        } else {
            nestedDict = [:]
        }
        
        nestedDict[cardTitle] = Array(set)
        preferences.sections[sectionName] = .nested(nestedDict)
    }
}

// MARK: - Tutorial Data Structures

struct TutorialData: Equatable {
    var show: Bool
    var cardFrame: CGRect
}

struct TutorialOverlayPreferenceKey: PreferenceKey {
    static var defaultValue: TutorialData = TutorialData(show: false, cardFrame: .zero)
    
    static func reduce(value: inout TutorialData, nextValue: () -> TutorialData) {
        let next = nextValue()
        if next.show {
            value = next
        }
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
            // Don't show carousel for singleMember flow (adding specific member from home)
            
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
        let lowerChipName = chipName.lowercased()
        let lowerSectionTitle = sectionTitle.lowercased()
        
        // "None of these apply" is ALWAYS Global Exclusive.
        // "Other" is Global Exclusive ONLY if it is in a top-level section named "Other" (The "Outer Other").
        // Otherwise, "Other" is just Local Exclusive (e.g. "Asian" -> "Other").
        
        let isNone = (lowerChipName == "none of these apply")
        let isOuterOther = (lowerChipName == "other" && lowerSectionTitle == "other")
        
        let isGlobalExclusive = isNone || isOuterOther
        let isLocalExclusive = (lowerChipName == "other" && !isOuterOther)
        
        if isGlobalExclusive {
            // GLOBAL EXCLUSIVE LOGIC
            // 1. Clear ALL other sections
            clearAllSections()
            
            // 2. Toggle this chip in this section
            var set = selections(for: sectionTitle)
            if set.contains(chipName) {
                set.remove(chipName)
            } else {
                set = [chipName]
            }
            syncRegionPreferences(from: set, for: sectionTitle)
            
        } else {
            // NORMAL or LOCAL EXCLUSIVE LOGIC
            
            // 1. Check if we need to clear any Global Exclusives from OTHER sections
            // (e.g. if "None of these apply" or "Outer Other" was selected, clear it)
            clearGlobalExclusivesFromOtherSections(currentSectionTitle: sectionTitle)
            
            var set = selections(for: sectionTitle)
            
            if isLocalExclusive {
                // Local Exclusive: Clear other chips in THIS section
                if set.contains(chipName) {
                    set.remove(chipName)
                } else {
                    set = [chipName]
                }
            } else {
                // Normal Option
                // 1. Remove Local Exclusives ("Other") in THIS section
                if let other = set.first(where: { $0.lowercased() == "other" }) {
                    set.remove(other)
                }
                // 2. Remove Global Exclusives ("None of these apply") in THIS section
                if let none = set.first(where: { $0.lowercased() == "none of these apply" }) {
                    set.remove(none)
                }
                
                // 3. Toggle
                if set.contains(chipName) {
                    set.remove(chipName)
                } else {
                    set.insert(chipName)
                }
            }
            syncRegionPreferences(from: set, for: sectionTitle)
        }
    }
    
    private func clearAllSections() {
        let stepSectionName = step.header.name
        // Just empty the whole nested dictionary for this step
        preferences.sections[stepSectionName] = .nested([:])
    }
    
    private func clearGlobalExclusivesFromOtherSections(currentSectionTitle: String) {
        let stepSectionName = step.header.name
        guard let value = preferences.sections[stepSectionName],
              case .nested(var nestedDict) = value else { return }
        
        var changed = false
        for (key, items) in nestedDict {
            // Skip the current section (we handle it separately)
            if key == currentSectionTitle { continue }
            
            // Check if this section has "None of these apply" OR is an "Outer Other" section
            let hasNone = items.contains(where: { $0.lowercased() == "none of these apply" })
            let isOuterOtherSection = (key.lowercased() == "other" && items.contains(where: { $0.lowercased() == "other" }))
            
            if hasNone || isOuterOtherSection {
                // Remove the global exclusive item(s)
                // For Outer Other, we clear the whole section since "Other" is likely the only item
                // For None, we filter it out
                
                if isOuterOtherSection {
                    nestedDict[key] = nil
                } else {
                    let newItems = items.filter { $0.lowercased() != "none of these apply" }
                    if newItems.isEmpty {
                        nestedDict[key] = nil
                    } else {
                        nestedDict[key] = newItems
                    }
                }
                changed = true
            }
        }
        
        if changed {
            preferences.sections[stepSectionName] = .nested(nestedDict)
        }
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

// MARK: - Meet Your Profile View

struct MeetYourProfileView: View {
    var onContinue: () -> Void
    @Environment(FamilyStore.self) var familyStore
    @Environment(MemojiStore.self) var memojiStore
    @Environment(AppNavigationCoordinator.self) var coordinator
    @State private var primaryMemberName: String = ""
    @FocusState private var isEditingPrimaryName: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Back Button
            HStack {
                Button(action: {
                    coordinator.navigateInBottomSheet(.preferencesAddedSuccess)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                }
                .padding(.leading, 16)
                Spacer()
            }
            .padding(.top, 24)

            // Avatar Section
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let image = memojiStore.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .background(Color(hex: memojiStore.backgroundColorHex ?? "#E0BBE4"))
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color(hex: memojiStore.backgroundColorHex ?? "#E0BBE4"))
                                .frame(width: 80, height: 80)
                        }
                    }
                    
                    Button {
                         // Navigation to avatar generation
                         memojiStore.previousRouteForGenerateAvatar = .meetYourProfile
                         coordinator.navigateInBottomSheet(.generateAvatar)
                    } label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                            .overlay(
                                Image("pen-line")
                                    .resizable()
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(.grayScale100)
                            )
                    }
                    .offset(x: 4, y: 4)
                }
            }
            .padding(.top, 16)

            // Greeting Title
            HStack(spacing: 8) {
                Text("Hello,")
                    .font(NunitoFont.bold.size(24))
                    .foregroundStyle(.grayScale150)
                
                HStack(spacing: 12) {
                    TextField("", text: $primaryMemberName)
                        .font(NunitoFont.semiBold.size(22))
                        .foregroundStyle(Color(hex: "#303030"))
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .focused($isEditingPrimaryName)
                        .submitLabel(.done)
                        .onSubmit { commitPrimaryName() }
                        .fixedSize(horizontal: true, vertical: false)
                    
                    Image("pen-line")
                        .resizable()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.grayScale100)
                        .onTapGesture { isEditingPrimaryName = true }
                }
                .padding(.horizontal, 20)
                .frame(minWidth: 144)
                .frame(maxWidth: 335)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isEditingPrimaryName ? Color(hex: "#EEF5E3") : .white))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#E3E3E3"), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
                .fixedSize(horizontal: true, vertical: false)
                .onTapGesture { isEditingPrimaryName = true }
                
                Text("!")
                    .font(NunitoFont.bold.size(24))
                    .foregroundStyle(.grayScale150)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Description
            Text("We’ve created a profile name and avatar based on your preferences. You can edit the name or avatar anytime to make it truly yours.")
                .font(ManropeFont.regular.size(14))
                .foregroundStyle(.grayScale100)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            
            // Continue Button
            Button(action: {
                commitPrimaryName()
                onContinue()
            }) {
                GreenCapsule(title: "Continue", width: 159)
                    .frame(width: 159)
            }
            .padding(.bottom, 24)
        }
        .onAppear {
            if let family = familyStore.family {
                // If it's the "Just Me" flow, backend defaults the member name to "Me"
                // but the family name to "Bite Buddy". We should show "Bite Buddy" here.
                if family.selfMember.name == "Me" && !family.name.isEmpty {
                    primaryMemberName = family.name
                } else {
                    primaryMemberName = family.selfMember.name
                }
            } else if let pending = familyStore.pendingSelfMember {
                primaryMemberName = pending.name
            } else {
                primaryMemberName = "Bite Buddy"
            }
        }
        .onChange(of: isEditingPrimaryName) { _, editing in
            if !editing {
                commitPrimaryName()
            }
        }
    }
    
    private func commitPrimaryName() {
        let trimmed = primaryMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        Task { @MainActor in
            if let family = familyStore.family {
                var me = family.selfMember
                guard me.name != trimmed else { return }
                me.name = trimmed
                await familyStore.editMember(me)
            } else if let pending = familyStore.pendingSelfMember {
                if pending.name != trimmed {
                    familyStore.updatePendingSelfMemberName(trimmed)
                }
            } else {
                // If neither exists, create pending self member
                familyStore.setPendingSelfMember(name: trimmed)
            }
        }
    }
}

#Preview("Meet Your Profile View") {
    let familyStore = FamilyStore()
    let memojiStore = MemojiStore()
    
    // Set up mock memoji data for preview
    memojiStore.backgroundColorHex = "#E0BBE4"
    memojiStore.image = UIImage(systemName: "person.circle.fill")
    
    return MeetYourProfileView(onContinue: {})
        .environment(familyStore)
        .environment(memojiStore)
}

// MARK: - Meet Your Profile Intro View

struct MeetYourProfileIntroView: View {
    @Environment(AppNavigationCoordinator.self) var coordinator
    
    var body: some View {
        VStack {
            Spacer()
            
            Button(action: {
                coordinator.navigateInBottomSheet(.meetYourProfile)
            }) {
                GreenCapsule(title: "Continue", width: 159)
                    .frame(width: 159)
            }
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Preferences Added Success Sheet

struct PreferencesAddedSuccessSheet: View {
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("Preferences added successfully!")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)
                
                Text("Your food preferences are saved. You can review them anytime, or edit a specific preference section by tapping Edit.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
                  
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            Button(action: onContinue) {
                GreenCapsule(title: "Continue")
                    .frame(width : 152 , height : 52)
            }
            .buttonStyle(.plain)
         
           
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 21)
        .padding(.top , 28)
        .padding(.bottom, 24)
    }
}
struct EditSectionBottomSheet: View {
    @EnvironmentObject private var store: Onboarding
    @Environment(FamilyStore.self) private var familyStore
    @Binding var isPresented: Bool
    
    let stepId: String
    let currentSectionIndex: Int
    let foodNotesStore: FoodNotesStore? = nil
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
    // Determine flow type: use .family if user has a family, otherwise use store's flow type
    private var effectiveFlowType: OnboardingFlowType {
        if let family = familyStore.family, !family.otherMembers.isEmpty {
            return .family
        }
        return .individual
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.grayScale60)
                    .frame(width: 60, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    isDragging = true
                                    dragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                isDragging = false
                                if value.translation.height > 100 || value.predictedEndTranslation.height > 200 {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        isPresented = false
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                
                if let step = store.step(for: stepId) {
                    DynamicOnboardingStepView(
                        step: step,
                        flowType: effectiveFlowType,
                        preferences: $store.preferences
                    )
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                    .transition(.opacity)
                }
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    isPresented = false
                }
            }) {
                GreenCapsule(
                    title: "Done",
                    takeFullWidth: false,
                    isLoading: false // Simplified for now to avoid dependency issues in preview/root
                )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .padding(.bottom, UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(36, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: -5)
        .ignoresSafeArea(edges: .bottom)
        .offset(y: dragOffset)
        .animation(isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: stepId)
    }
}
