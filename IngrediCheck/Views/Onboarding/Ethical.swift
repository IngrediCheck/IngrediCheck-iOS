//
//  Ethical.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 16/10/25.
//

import SwiftUI

struct Ethical: View {
    @State var onboardingFlowType: OnboardingFlowType
    @Binding var preferences: Preferences
    @State var arr: [ChipsModel] = [
        ChipsModel(name: "Animal welfare focused", icon: "beef"),
        ChipsModel(name: "Fair trade", icon: "handshake"),
        ChipsModel(name: "Sustainable fishing / no overfished species", icon: "fish"),
        ChipsModel(name: "Low carbon footprint foods", icon: "recycle"),
        ChipsModel(name: "Water footprint concerns", icon: "water-drop"),
        ChipsModel(name: "Palm-oil free", icon: "palm oil"),
        ChipsModel(name: "Plastic-free packaging", icon: "stop"),
        ChipsModel(name: "Other", icon: "other")
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                
                if onboardingFlowType == .individual {
                    onboardingSheetTitle(title: "What ethical or environmental values are important to you?")
                    
                    onboardingSheetSubtitle(subtitle: "Select the causes that matter most when it comes to the food you eat.", onboardingFlowType: onboardingFlowType)
                } else {
                    onboardingSheetTitle(title: "What ethical or environmental values matter to your IngrediFam?")
                    
                    onboardingSheetSubtitle(subtitle: "Select causes that shape your food choices.", onboardingFlowType: onboardingFlowType)
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
                            var set = Set(preferences.ethical ?? [])
                            if set.contains(ele.name) {
                                set.remove(ele.name)
                            } else {
                                set.insert(ele.name)
                            }
                            preferences.ethical = Array(set)
                        }, isSelected: (preferences.ethical ?? []).contains(ele.name)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    Ethical(onboardingFlowType: .individual, preferences: .constant(Preferences()))
}
