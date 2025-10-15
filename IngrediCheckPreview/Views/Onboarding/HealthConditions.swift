//
//  HealthConditions.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

struct HealthConditions: View {
    @State var onboardingFlowType: OnboardingFlowType
    @State var arr: [ChipsModel] = [
        ChipsModel(name: "Diabetes", icon: "diabetes"),
        ChipsModel(name: "Hypertension", icon: "hypertension"),
        ChipsModel(name: "Kidney Disease", icon: "kidney disease"),
        ChipsModel(name: "Heart Health", icon: "heart health"),
        ChipsModel(name: "PKU (phenyalanine-sensitive)", icon: "pku (phenyalanine-sensitive)"),
        ChipsModel(name: "Anti-inflammatory medical diet", icon: "anti-inflammatory medical diet"),
        ChipsModel(name: "Celiac disease", icon: "celiac disease"),
        ChipsModel(name: "Other", icon: "other")
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
                        image: ele.icon
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    HealthConditions(onboardingFlowType: .individual)
}
