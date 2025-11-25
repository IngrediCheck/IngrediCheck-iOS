//
//  HealthConditions.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

struct HealthConditions: View {
    @State var onboardingFlowType: OnboardingFlowType
    @Binding var preferences: Preferences
    @State var arr: [ChipsModel] = [
        ChipsModel(name: "Diabetes", icon: "🍭"),
        ChipsModel(name: "Hypertension", icon: "💊"),
        ChipsModel(name: "Kidney Disease", icon: "🩺"),
        ChipsModel(name: "Heart Health", icon: "🫀"),
        ChipsModel(name: "PKU (phenyalanine-sensitive)", icon: "🧬"),
        ChipsModel(name: "Anti-inflammatory medical diet", icon: "🥗"),
        ChipsModel(name: "Celiac disease", icon: "🥖"),
        ChipsModel(name: "Other", icon: "✏️")
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                
                if onboardingFlowType == .individual {
                    onboardingSheetTitle(title: "Do you follow any special diets or have health conditions?")
                    
                    onboardingSheetSubtitle(subtitle: "This helps us recommend meals that work for you.", onboardingFlowType: onboardingFlowType)
                } else {
                    onboardingSheetTitle(title: "Any doctor diets or health conditions in your IngrediFam?")
                    
                    onboardingSheetSubtitle(subtitle: "This helps us tailor recommendations better.", onboardingFlowType: onboardingFlowType)
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
                            var set = Set(preferences.healthConditions ?? [])
                            if set.contains(ele.name) {
                                set.remove(ele.name)
                            } else {
                                set.insert(ele.name)
                            }
                            preferences.healthConditions = Array(set)
                        }, isSelected: (preferences.healthConditions ?? []).contains(ele.name)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    HealthConditions(onboardingFlowType: .individual, preferences: .constant(Preferences()))
}
