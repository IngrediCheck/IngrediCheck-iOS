//
//  Allergies.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

struct Allergies: View {
    
    @State var onboardingFlowType: OnboardingFlowType
    @State var arr: [ChipsModel] = [
        ChipsModel(name: "Peanuts", icon: "peanuts"),
        ChipsModel(name: "Tree nuts", icon: "tree nuts"),
        ChipsModel(name: "Dairy", icon: "dairy"),
        ChipsModel(name: "Eggs", icon: "eggs"),
        ChipsModel(name: "Soy", icon: "soy"),
        ChipsModel(name: "Wheat", icon: "wheat"),
        ChipsModel(name: "Fish", icon: "fish"),
        ChipsModel(name: "Shellfish", icon: "shellfish"),
        ChipsModel(name: "Sesame", icon: "sesame"),
        ChipsModel(name: "Celery", icon: "celery"),
        ChipsModel(name: "Lupin", icon: "lupin"),
        ChipsModel(name: "Sulphites", icon: "sulphites"),
        ChipsModel(name: "Mustard", icon: "mustard"),
        ChipsModel(name: "Molluscs", icon: "molluscs"),
        ChipsModel(name: "Other", icon: "other")
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                
                if onboardingFlowType == .individual {
                    onboardingSheetTitle(title: "Got any allergies we should keep in mind?")
                    
                    onboardingSheetSubtitle(subtitle: "Choose all that apply so we can give you smarter food tips.", onboardingFlowType: onboardingFlowType)
                } else {
                    onboardingSheetTitle(title: "Does anyone in your IngrediFam have allergies we should know ?")
                    
                    onboardingSheetSubtitle(subtitle: "Select all that apply to keep meals worry-free.", onboardingFlowType: onboardingFlowType)
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
            
            HStack {
                Spacer()
                
                GreenCircle(circleSize: 52)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 28)
        .padding(.bottom, 16)
    }
}

#Preview {
    Allergies(onboardingFlowType: .family)
}
