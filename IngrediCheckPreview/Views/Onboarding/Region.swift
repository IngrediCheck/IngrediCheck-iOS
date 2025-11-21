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
                ChipsModel(name: "Ayurveda", icon: nil),
                ChipsModel(name: "Hindu food traditions", icon: nil),
                ChipsModel(name: "Jain diet", icon: nil),
                ChipsModel(name: "Other", icon: nil)
            ]
        ),
        SectionedChipModel(
            title: "Africa",
            subtitle: nil,
            chips: [
                ChipsModel(name: "Rastafarian Ital diet", icon: nil),
                ChipsModel(name: "Ethiopian Orthodox fasting", icon: nil),
                ChipsModel(name: "Other", icon: nil)
            ]
        ),
        SectionedChipModel(
            title: "Middle East & Mediterranean",
            subtitle: nil,
            chips: [
                ChipsModel(name: "Halal (Islamic dietary laws)", icon: nil),
                ChipsModel(name: "Kosher (Jewish dietary laws)", icon: nil),
                ChipsModel(name: "Greek / Mediterranean diets", icon: nil),
                ChipsModel(name: "Other", icon: nil)
            ]
        ),
        SectionedChipModel(
            title: "East Asia",
            subtitle: nil,
            chips: [
                ChipsModel(name: "Traditional Chinese Medicine (TCM)", icon: nil),
                ChipsModel(name: "Buddhist food rules", icon: nil),
                ChipsModel(name: "Japanese Macrobiotic diet", icon: nil),
                ChipsModel(name: "Other", icon: nil)
            ]
        ),
        SectionedChipModel(
            title: "Western / Native traditions",
            subtitle: nil,
            chips: [
                ChipsModel(name: "Native American traditions", icon: nil),
                ChipsModel(name: "Christian traditions", icon: nil),
                ChipsModel(name: "Other", icon: nil)
            ]
        ),
        SectionedChipModel(
            title: "Seventh-day Adventist",
            subtitle: nil,
            chips: [
                ChipsModel(name: "Seventh-day Adventist", icon: nil)
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
                        RegionSectionRow(
                            section: section,
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
                        .foregroundStyle(.grayScale150)

                    Circle()
                        .fill(.grayScale30)
                        .foregroundStyle(.grayScale60)
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
                .background(
                    Capsule()
                        .fill(.grayScale10)
                )
                .overlay(
                    Capsule()
                        .stroke(lineWidth: 1)
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
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    )
                )
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    Region(onboardingFlowType: .individual, preferences: .constant(Preferences()))
}
