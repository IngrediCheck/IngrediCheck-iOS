//
//  Avoid.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

struct Avoid: View {
    @State var onboardingFlowType: OnboardingFlowType
    @Binding var preferences: Preferences
    @State var arr: [Card] = [
        Card(title: "Oils & Fats", subTitle: "In fats or oils, what do you avoid?", color: .avatarYellow, chips: [
            ChipsModel(name: "Hydrogenated oils / Trans fats", icon: "🧈"),
            ChipsModel(name: "Canola / Seed oils", icon: "🌾"),
            ChipsModel(name: "Palm oil", icon: "🌴"),
            ChipsModel(name: "Corn / High-frectose corn syrup", icon: "🌽")
        ]),
        Card(title: "Animal-Based", subTitle: "Any animal products you don't consume?", color: .avatarPruple, chips: [
            ChipsModel(name: "Pork", icon: "🐖"),
            ChipsModel(name: "Beef", icon: "🐄"),
            ChipsModel(name: "Honey", icon: "🍯"),
            ChipsModel(name: "Gelatin / Rennet", icon: "🧂"),
            ChipsModel(name: "Shellfish", icon: "🦐"),
            ChipsModel(name: "Insects", icon: "🐜"),
            ChipsModel(name: "Seafood (fish)", icon: "🐟"),
            ChipsModel(name: "Lard / Animal fat", icon: "🍖")
        ]),
        Card(title: "Stimulants & Substances", subTitle: "Do you avoid these?", color: .avatarGreen, chips: [
            ChipsModel(name: "Alcohol", icon: "🍷"),
            ChipsModel(name: "Caffeine", icon: "☕")
        ]),
        Card(title: "Additives & Sweeteners", subTitle: "Do you stay away from processed ingredients?", color: .avatarOrange, chips: [
            ChipsModel(name: "MSG", icon: "⚗️"),
            ChipsModel(name: "Artificial sweeteners", icon: "🍬"),
            ChipsModel(name: "Preservatives", icon: "🧂"),
            ChipsModel(name: "Refined sugar", icon: "🍚"),
            ChipsModel(name: "Corn syrup / HFCS", icon: "🌽"),
            ChipsModel(name: "Stevia ? Monk fruit", icon: "🍈"),
        ]),
        Card(title: "Plant-Based Restrictions", subTitle: "Any plant foods you avoid?", color: .avatarGreen, chips: [
            ChipsModel(name: "Nightshades (paprika, pappers, etc.)", icon: "🍅"),
            ChipsModel(name: "Garlic / Onion", icon: "🧄")
        ])
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                
                if onboardingFlowType == .individual {
                    onboardingSheetTitle(title: "Anything you avoid in your diet?")
                } else {
                    onboardingSheetTitle(title: "Anything your IngrediFam avoids?")
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
            
            StackedCards(
                cards: arr,
                isChipSelected: { card, chip in
                    avoidSelection(for: card.title).contains(chip.name)
                },
                onChipTap: { card, chip in
                    toggleAvoidSelection(for: card.title, chipName: chip.name)
                }
            )
            .padding(.horizontal, 20)
        }
    }
    
    private func avoidSelection(for title: String) -> [String] {
        guard let avoid = preferences.avoid,
              let keyPath = avoidKey(for: title) else { return [] }
        return avoid[keyPath: keyPath]
    }
    
    private func toggleAvoidSelection(for title: String, chipName: String) {
        guard let keyPath = avoidKey(for: title) else { return }
        
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
        var list = avoid[keyPath: keyPath]
        if let idx = list.firstIndex(of: chipName) {
            list.remove(at: idx)
        } else {
            list.append(chipName)
        }
        avoid[keyPath: keyPath] = list
        preferences.avoid = avoid
    }
    
    private func avoidKey(for title: String) -> WritableKeyPath<AvoidPreferences, [String]>? {
        switch title {
        case "Oils & Fats":
            return \.oilsFats
        case "Animal-Based":
            return \.animalBased
        case "Stimulants & Substances":
            return \.stimulantsSubstances
        case "Additives & Sweeteners":
            return \.additivesSweeteners
        case "Plant-Based Restrictions":
            return \.plantBasedRestrictions
        default:
            return nil
        }
    }
}

#Preview {
    Avoid(onboardingFlowType: .family, preferences: .constant(Preferences()))
}
