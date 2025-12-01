//
//  Intolerances.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

struct Intolerances: View {
    @State var onboardingFlowType: OnboardingFlowType
    @Binding var preferences: Preferences
    @State var arr: [ChipsModel] = [
        ChipsModel(name: "Lactose", icon: "lactose"),
        ChipsModel(name: "Fructose", icon: "fructose"),
        ChipsModel(name: "Histamine", icon: "histamine"),
        ChipsModel(name: "Gluten / wheat", icon: "wheat"),
        ChipsModel(name: "Fodmap", icon: "fodmap"),
        ChipsModel(name: "Other", icon: "other")
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                
                if onboardingFlowType == .individual {
                    onboardingSheetTitle(title: "Any sensitivities that make eating tricky?")
                    
                    onboardingSheetSubtitle(subtitle: "We’ll make sure your food suggestions avoid these.", onboardingFlowType: onboardingFlowType)
                } else {
                    onboardingSheetTitle(title: "Any sensitivities or intolerances in your IngrediFam?")
                    
                    onboardingSheetSubtitle(subtitle: "We’ll avoid foods that cause discomfort.", onboardingFlowType: onboardingFlowType)
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
                            var set = Set(preferences.intolerances ?? [])
                            if set.contains(ele.name) {
                                set.remove(ele.name)
                            } else {
                                set.insert(ele.name)
                            }
                            preferences.intolerances = Array(set)
                        }, isSelected: (preferences.intolerances ?? []).contains(ele.name)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    Intolerances(onboardingFlowType: .family, preferences: .constant(Preferences()))
}
