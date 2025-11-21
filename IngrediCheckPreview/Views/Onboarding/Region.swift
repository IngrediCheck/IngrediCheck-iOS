//
//  Region.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

struct Region: View {
    @State var onboardingFlowType: OnboardingFlowType
    @Binding var preferences: Preferences
    
    /// Region sections with the new grouped UI
    @State private var sections: [SectionedChipModel] = [
        SectionedChipModel(
            title: "India & South Asia",
            subtitle: nil,
            chips: [
                ChipsModel(name: "Ayurveda", icon: "🌿"),
                ChipsModel(name: "Hindu food traditions", icon: "🕉"),
                ChipsModel(name: "Jain diet", icon: "🧘‍♂️"),
                ChipsModel(name: "Other", icon: "other")
            ]
        ),
        SectionedChipModel(
            title: "Africa",
            subtitle: nil,
            chips: [
                ChipsModel(name: "Rastafarian Ital diet", icon: "anti-inflammatory medical diet"),
                ChipsModel(name: "Ethiopian Orthodox fasting", icon: "🥖"),
                ChipsModel(name: "Other", icon: "other")
            ]
        ),
        SectionedChipModel(
            title: "Middle East & Mediterranean",
            subtitle: nil,
            chips: [
                ChipsModel(name: "Halal (Islamic dietary laws)", icon: "☪️"),
                ChipsModel(name: "Kosher (Jewish dietary laws)", icon: "✡"),
                ChipsModel(name: "Greek / Mediterranean diets", icon: "🫒"),
                ChipsModel(name: "Other", icon: "other")
            ]
        ),
        SectionedChipModel(
            title: "East Asia",
            subtitle: nil,
            chips: [
                ChipsModel(name: "Traditional Chinese Medicine (TCM)", icon: "🧧"),
                ChipsModel(name: "Buddhist food rules", icon: "🧘"),
                ChipsModel(name: "Japanese Macrobiotic diet", icon: "🍙"),
                ChipsModel(name: "Other", icon: "other")
            ]
        ),
        SectionedChipModel(
            title: "Western / Native traditions",
            subtitle: nil,
            chips: [
                ChipsModel(name: "Native American traditions", icon: "🪶"),
                ChipsModel(name: "Christian traditions", icon: "✝️"),
                ChipsModel(name: "Other", icon: "other")
            ]
        ),
        SectionedChipModel(
            title: "Seventh-day Adventist",
            subtitle: nil,
            chips: [
                ChipsModel(name: "Seventh-day Adventist", icon: "✝️")
            ]
        )
    ]
    
    /// Tracks which region sections are currently expanded
    @State private var expandedSectionIds: Set<String> = []
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                
                if onboardingFlowType == .individual {
                    onboardingSheetTitle(title: "Where are you from? This helps us customize your experience!")
                    
                    onboardingSheetSubtitle(subtitle: "Pick your region(s) or cultural practices.", onboardingFlowType: onboardingFlowType)
                } else {
                    onboardingSheetTitle(title: "Where does your IngrediFam draw its food traditions from?")
                    
                    onboardingSheetSubtitle(subtitle: "Select your region or cultural roots.", onboardingFlowType: onboardingFlowType)
                }
                
            }
            .padding(.horizontal, 20)
            
            
            if onboardingFlowType == .family {
                VStack(alignment: .leading, spacing: 8) {
                    FamilyCarouselView()
                    
                    onboardingSheetFamilyMemberSelectNote()
                }
                .padding(.leading, 20)
            }
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sections) { section in
                        if section.chips.count > 1 {
                            RegionSectionRow(
                                section: section,
                                isSectionSelected: !regionSelection(for: section.title).isEmpty,
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
                                    regionSelection(for: section.title).contains(chip.name)
                                },
                                onChipTap: { chip in
                                    toggleRegionSelection(for: section.title, chipName: chip.name)
                                }
                            )
                        } else if let singleChip = section.chips.first {
                            VStack(alignment: .leading, spacing: 8) {
                                IngredientsChips(
                                    title: singleChip.name,
                                    image: singleChip.icon,
                                    onClick: {
                                        toggleRegionSelection(for: section.title, chipName: singleChip.name)
                                    },
                                    isSelected: regionSelection(for: section.title).contains(singleChip.name)
                                )
                                
                                IngredientsChips(
                                    title: "Other",
                                    image: "other",
                                    onClick: {
                                        toggleOtherSelection(chipName: "Other")
                                    },
                                    isSelected: otherSelection().contains("Other")
                                )
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
            }
            .frame(height: UIScreen.main.bounds.height * 0.3)
        }
    }
    
    private func ensureRegionPreferences() {
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
    }
    
    private func regionSelection(for title: String) -> [String] {
        guard let region = preferences.region,
              let keyPath = regionKey(for: title) else { return [] }
        return region[keyPath: keyPath]
    }
    
    private func toggleRegionSelection(for title: String, chipName: String) {
        guard let keyPath = regionKey(for: title) else { return }
        
        ensureRegionPreferences()
        guard var region = preferences.region else { return }
        
        var list = region[keyPath: keyPath]
        if let idx = list.firstIndex(of: chipName) {
            list.remove(at: idx)
        } else {
            list.append(chipName)
        }
        region[keyPath: keyPath] = list
        preferences.region = region
    }
    
    private func otherSelection() -> [String] {
        guard let region = preferences.region else { return [] }
        return region.other
    }
    
    private func toggleOtherSelection(chipName: String) {
        ensureRegionPreferences()
        guard var region = preferences.region else { return }
        
        var list = region.other
        if let idx = list.firstIndex(of: chipName) {
            list.remove(at: idx)
        } else {
            list.append(chipName)
        }
        region.other = list
        preferences.region = region
    }
    
    private func regionKey(for title: String) -> WritableKeyPath<RegionPreferences, [String]>? {
        switch title {
        case "India & South Asia":
            return \.indiaSouthAsia
        case "Africa":
            return \.africa
        case "East Asia":
            return \.eastAsian
        case "Middle East & Mediterranean":
            return \.middleEastMediterranean
        case "Western / Native traditions":
            return \.westernNative
        case "Seventh-day Adventist":
            return \.seventhDayAdventist
        default:
            return nil
        }
    }
}

// MARK: - Region section row

private struct RegionSectionRow: View {
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

#Preview {
    Region(onboardingFlowType: .individual, preferences: .constant(Preferences()))
}
