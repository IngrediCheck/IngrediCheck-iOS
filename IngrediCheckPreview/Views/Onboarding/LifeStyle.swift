//
//  LifeStyle.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

struct LifeStyle: View {
    @State var onboardingFlowType: OnboardingFlowType
    @Binding var preferences: Preferences
    @State var arr: [Card] = [
        Card(title: "Plant & Balance", subTitle: "Do you follow a lant-forward or flexible eating style?", color: .avatarYellow, chips: [
            ChipsModel(name: "Vegetarian", icon: "vegetarian"),
            ChipsModel(name: "Vegan", icon: "soy"),
            ChipsModel(name: "Flexitarian", icon: "flexitarian"),
            ChipsModel(name: "Reducetarian", icon: "reducetarian"),
            ChipsModel(name: "Pescatarian", icon: "fish"),
            ChipsModel(name: "Other", icon: "other")
        ]),
        Card(title: "Quality & Source", subTitle: "Do you care about where your food comes from and how it’s grown?", color: .avatarPruple, chips: [
            ChipsModel(name: "Organic Only", icon: "organic only"),
            ChipsModel(name: "Non-GMO", icon: "pku (phenyalanine-sensitive)"),
            ChipsModel(name: "Locally Sourced", icon: "locally sourced"),
            ChipsModel(name: "Seasonal Eater", icon: "seasonal eater")
        ]),
        Card(title: "Sustainable Living", subTitle: "Are you mindful of waste, packaging, and ingredient transparency?", color: .primary400, chips: [
            ChipsModel(name: "Zero-Waste / Minimal Packing", icon: "globe"),
            ChipsModel(name: "Clean Label", icon: "none of these apply")
        ])
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                
                if onboardingFlowType == .individual {
                    onboardingSheetTitle(title: "What’s your way of eating?")
                } else {
                    onboardingSheetTitle(title: "What’s your IngrediFam’s food lifestyle?")
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
                    lifestyleSelection(for: card.title).contains(chip.name)
                },
                onChipTap: { card, chip in
                    toggleLifestyleSelection(for: card.title, chipName: chip.name)
                }
            )
            .padding(.horizontal, 20)
        }
    }
    
    private func lifestyleSelection(for title: String) -> [String] {
        guard let lifestyle = preferences.lifestyle,
              let keyPath = lifestyleKey(for: title) else { return [] }
        return lifestyle[keyPath: keyPath]
    }
    
    private func toggleLifestyleSelection(for title: String, chipName: String) {
        guard let keyPath = lifestyleKey(for: title) else { return }
        
        if preferences.lifestyle == nil {
            preferences.lifestyle = LifestylePreferences(
                plantBalance: [],
                qualitySource: [],
                sustainableLiving: []
            )
        }
        
        guard var lifestyle = preferences.lifestyle else { return }
        var list = lifestyle[keyPath: keyPath]
        if let idx = list.firstIndex(of: chipName) {
            list.remove(at: idx)
        } else {
            list.append(chipName)
        }
        lifestyle[keyPath: keyPath] = list
        preferences.lifestyle = lifestyle
    }
    
    private func lifestyleKey(for title: String) -> WritableKeyPath<LifestylePreferences, [String]>? {
        switch title {
        case "Plant & Balance":
            return \.plantBalance
        case "Quality & Source":
            return \.qualitySource
        case "Sustainable Living":
            return \.sustainableLiving
        default:
            return nil
        }
    }
}

#Preview {
    LifeStyle(onboardingFlowType: .family, preferences: .constant(Preferences()))
}
