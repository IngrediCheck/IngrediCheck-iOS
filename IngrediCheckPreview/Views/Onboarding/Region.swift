//
//  Region.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

struct Region: View {
    @State var onboardingFlowType: OnboardingFlowType
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
    Region(onboardingFlowType: .individual)
}
