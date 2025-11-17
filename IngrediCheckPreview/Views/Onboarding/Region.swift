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
    @State var arr: [ChipsModel] = [
        ChipsModel(name: "India & South Asia", icon: nil),
        ChipsModel(name: "Africa", icon: nil),
        ChipsModel(name: "East Asia", icon: nil),
        ChipsModel(name: "Middle East & Mediterranean", icon: nil),
        ChipsModel(name: "Western / Native traditions", icon: nil),
        ChipsModel(name: "Seventh-day Adventist", icon: nil),
        ChipsModel(name: "Other", icon: "other")
    ]
    
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
            
            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(arr) { ele in
                    IngredientsChips(
                        title: ele.name,
                        image: ele.icon,
                        onClick: {
                            toggleRegionSelection(ele.name)
                        }, isSelected: isRegionSelected(ele.name)
                    )
                }
            }
            .padding(.horizontal, 20)
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
    
    private func isRegionSelected(_ name: String) -> Bool {
        guard let region = preferences.region else { return false }
        switch name {
        case "India & South Asia": return region.indiaSouthAsia.contains(name)
        case "Africa": return region.africa.contains(name)
        case "East Asia": return region.eastAsian.contains(name) || region.eastAsian.contains("East Asian")
        case "Middle East & Mediterranean": return region.middleEastMediterranean.contains(name) || region.middleEastMediterranean.contains("Middle East & Mediterranean")
        case "Western / Native traditions": return region.westernNative.contains(name)
        case "Seventh-day Adventist": return region.seventhDayAdventist.contains(name)
        case "Other": return region.other.contains(name)
        default: return false
        }
    }
    
    private func toggleRegionSelection(_ name: String) {
        ensureRegionPreferences()
        guard var region = preferences.region else { return }
        let toggle: (inout [String], String) -> Void = { arr, value in
            if let idx = arr.firstIndex(of: value) {
                arr.remove(at: idx)
            } else {
                arr.append(value)
            }
        }
        switch name {
        case "India & South Asia":
            toggle(&region.indiaSouthAsia, name)
        case "Africa":
            toggle(&region.africa, name)
        case "East Asia":
            // store normalized as "East Asian" for compatibility
            toggle(&region.eastAsian, "East Asian")
        case "Middle East & Mediterranean":
            toggle(&region.middleEastMediterranean, "Middle East & Mediterranean")
        case "Western / Native traditions":
            toggle(&region.westernNative, name)
        case "Seventh-day Adventist":
            toggle(&region.seventhDayAdventist, name)
        case "Other":
            toggle(&region.other, name)
        default:
            break
        }
        preferences.region = region
    }
}

#Preview {
    Region(onboardingFlowType: .individual, preferences: .constant(Preferences()))
}
