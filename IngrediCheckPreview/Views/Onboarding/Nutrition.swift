//
//  Nutrition.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 16/10/25.
//

import SwiftUI

struct Nutrition: View {
    @State var onboardingFlowType: OnboardingFlowType
    @State var arr: [Card] = [
        Card(title: "Macronutrient Goals", subTitle: "Do you want to balance your proteins, carbs, and fats or focus on one?", color: .avatarPink, chips: [
            ChipsModel(name: "High Protein", icon: "chicken"),
            ChipsModel(name: "Low Carb", icon: "Cucumber"),
            ChipsModel(name: "Low Fat", icon: "Avacardo"),
            ChipsModel(name: "Balanced Macros", icon: "weight-machine")
        ]),
        Card(title: "Sugar & Fiber", subTitle: "Do you prefer low sugar or high-fiber foods for better digestion and energy?", color: .avatarBlue, chips: [
            ChipsModel(name: "Low Sugar", icon: "fructose"),
            ChipsModel(name: "Sugar-Free", icon: "diabetes"),
            ChipsModel(name: "High Fiber", icon: "wheat")
        ]),
        Card(title: "Diet Frameworks & Patterns", subTitle: "Do you follow a structured eating pan or experiment with fasting?", color: .avatarOrange, chips: [
            ChipsModel(name: "Keto", icon: "Avacardo"),
            ChipsModel(name: "DASH", icon: "water-drop"),
            ChipsModel(name: "Paleo", icon: "meat"),
            ChipsModel(name: "Mediterranean", icon: "coconut"),
            ChipsModel(name: "Whole30", icon: "anti-inflammatory medical diet"),
            ChipsModel(name: "Fasting", icon: "clock"),
            ChipsModel(name: "Other", icon: "other")
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
            
            StackedCards(cards: arr)
                .padding(.horizontal, 20)
        }
    }
}

#Preview {
    Nutrition(onboardingFlowType: .individual)
}
