//
//  Nutrition.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 16/10/25.
//

import SwiftUI

struct Nutrition: View {
    @State var onboardingFlowType: OnboardingFlowType
    @Binding var preferences: Preferences
    @State var arr: [Card] = [
        Card(title: "Macronutrient Goals", subTitle: "Do you want to balance your proteins, carbs, and fats or focus on one?", color: .avatarPink, chips: [
            ChipsModel(name: "High Protein", icon: "🍗"),
            ChipsModel(name: "Low Carb", icon: "🥒"),
            ChipsModel(name: "Low Fat", icon: "🥑"),
            ChipsModel(name: "Balanced Macros", icon: "⚖️")
        ]),
        Card(title: "Sugar & Fiber", subTitle: "Do you prefer low sugar or high-fiber foods for better digestion and energy?", color: .avatarBlue, chips: [
            ChipsModel(name: "Low Sugar", icon: "🍓"),
            ChipsModel(name: "Sugar-Free", icon: "🍭"),
            ChipsModel(name: "High Fiber", icon: "🌾")
        ]),
        Card(title: "Diet Frameworks & Patterns", subTitle: "Do you follow a structured eating pan or experiment with fasting?", color: .avatarOrange, chips: [
            ChipsModel(name: "Keto", icon: "🥑"),
            ChipsModel(name: "DASH", icon: "💧"),
            ChipsModel(name: "Paleo", icon: "🥩"),
            ChipsModel(name: "Mediterranean", icon: "🫒"),
            ChipsModel(name: "Whole30", icon: "🥗"),
            ChipsModel(name: "Fasting", icon: "🕑"),
            ChipsModel(name: "Other", icon: "✏️")
        ])
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                
                if onboardingFlowType == .individual {
                    onboardingSheetTitle(title: "What’s your nutrition focus right now?")
                } else {
                    onboardingSheetTitle(title: "What’s your IngrediFam’s nutrition focus?")
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
                    nutritionSelection(for: card.title).contains(chip.name)
                },
                onChipTap: { card, chip in
                    toggleNutritionSelection(for: card.title, chipName: chip.name)
                }
            )
            .padding(.horizontal, 20)
        }
    }
    
    private func nutritionSelection(for title: String) -> [String] {
        guard let nutrition = preferences.nutrition,
              let keyPath = nutritionKey(for: title) else { return [] }
        return nutrition[keyPath: keyPath]
    }
    
    private func toggleNutritionSelection(for title: String, chipName: String) {
        guard let keyPath = nutritionKey(for: title) else { return }
        
        if preferences.nutrition == nil {
            preferences.nutrition = NutritionPreferences(
                macronutrientGoals: [],
                sugarFiber: [],
                dietFrameworks: []
            )
        }
        
        guard var nutrition = preferences.nutrition else { return }
        var list = nutrition[keyPath: keyPath]
        if let idx = list.firstIndex(of: chipName) {
            list.remove(at: idx)
        } else {
            list.append(chipName)
        }
        nutrition[keyPath: keyPath] = list
        preferences.nutrition = nutrition
    }
    
    private func nutritionKey(for title: String) -> WritableKeyPath<NutritionPreferences, [String]>? {
        switch title {
        case "Macronutrient Goals":
            return \.macronutrientGoals
        case "Sugar & Fiber":
            return \.sugarFiber
        case "Diet Frameworks & Patterns":
            return \.dietFrameworks
        default:
            return nil
        }
    }
}

#Preview {
    Nutrition(onboardingFlowType: .individual, preferences: .constant(Preferences()))
}
