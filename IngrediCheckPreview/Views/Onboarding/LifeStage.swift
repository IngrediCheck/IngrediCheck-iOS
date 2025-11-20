//
//  LifeStage.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

struct LifeStage: View {
    @State var onboardingFlowType: OnboardingFlowType
    @Binding var preferences: Preferences
    @State var arr: [ChipsModel] = [
        ChipsModel(name: "Kids Baby-friendly foods", icon: "kids baby-friendly foods"),
        ChipsModel(name: "Toddler pickey-eating adaptations", icon: "toddler pickey-eating adaptations"),
        ChipsModel(name: "Pregnancy Prenatal nutrition", icon: "pregnancy prenatal nutrition"),
        ChipsModel(name: "Breastfeeding diets", icon: "breastfeeding diets"),
        ChipsModel(name: "Senior-friendly", icon: "senior-friendly"),
        ChipsModel(name: "None of these apply", icon: "none of these apply")
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                
                if onboardingFlowType == .individual {
                    onboardingSheetTitle(title: "Do you have special needs we should keep in mind?")
                    
                    onboardingSheetSubtitle(subtitle: "Select all that apply, this helps us tailor tips for you.", onboardingFlowType: onboardingFlowType)
                } else {
                    onboardingSheetTitle(title: "Does anyone in your IngrediFam have special life stage needs?")
                    
                    onboardingSheetSubtitle(subtitle: "Select all that apply so tips match every life stage.", onboardingFlowType: onboardingFlowType)
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
                            var set = Set(preferences.lifeStage ?? [])
                            if set.contains(ele.name) {
                                set.remove(ele.name)
                            } else {
                                set.insert(ele.name)
                            }
                            preferences.lifeStage = Array(set)
                        }, isSelected: (preferences.lifeStage ?? []).contains(ele.name)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    LifeStage(onboardingFlowType: .family, preferences: .constant(Preferences()))
}
