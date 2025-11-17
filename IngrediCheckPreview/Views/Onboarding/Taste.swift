//
//  Taste.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 16/10/25.
//

import SwiftUI

struct Taste: View {
    @State var onboardingFlowType: OnboardingFlowType
    @State var arr: [ChipsModel] = [
        ChipsModel(name: "Spicy lover", icon: "red-chilli"),
        ChipsModel(name: "Avoid Spicy", icon: "stop"),
        ChipsModel(name: "Sweet tooth", icon: "cheese-cake"),
        ChipsModel(name: "Avoid slimy textures", icon: "Cucumber"),
        ChipsModel(name: "Avoid bitter foods", icon: "bitter foods"),
        ChipsModel(name: "Other", icon: "other"),
        ChipsModel(name: "Crunchy / Soft preferences", icon: "cookie"),
        ChipsModel(name: "Low-sweet preference", icon: "honey")
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                
                if onboardingFlowType == .individual {
                    onboardingSheetTitle(title: "What are your taste and texture preferences?")
                    
                    onboardingSheetSubtitle(subtitle: "Choose what you love or avoid when it comes to flavors and textures.", onboardingFlowType: onboardingFlowType)
                } else {
                    onboardingSheetTitle(title: "What tastes and textures does your family prefer?")
                    
                    onboardingSheetSubtitle(subtitle: "Customize tastes so every plate feels just right.", onboardingFlowType: onboardingFlowType)
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
    Taste(onboardingFlowType: .family)
}
