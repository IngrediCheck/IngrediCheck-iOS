//
//  Allergies.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

struct Allergies: View {
    
    @State var onboardingFlowType: OnboardingFlowType
    @Binding var preferences: Preferences
    @State var arr: [ChipsModel] = [
        ChipsModel(name: "Peanuts", icon: "🥜"),
        ChipsModel(name: "Tree nuts", icon: "🌰"),
        ChipsModel(name: "Dairy", icon: "🥛"),
        ChipsModel(name: "Eggs", icon: "🥚"),
        ChipsModel(name: "Soy", icon: "🌱"),
        ChipsModel(name: "Wheat", icon: "🌾"),
        ChipsModel(name: "Fish", icon: "🐟"),
        ChipsModel(name: "Shellfish", icon: "🦐"),
        ChipsModel(name: "Sesame", icon: "⚪"),
        ChipsModel(name: "Celery", icon: "🥬"),
        ChipsModel(name: "Lupin", icon: "🫘"),
        ChipsModel(name: "Sulphites", icon: "🧂"),
        ChipsModel(name: "Mustard", icon: "🟡"),
        ChipsModel(name: "Molluscs", icon: "🐚"),
        ChipsModel(name: "Other", icon: "✏")
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
                        image: ele.icon,
                        onClick: {
                            var set = Set(preferences.allergies ?? [])
                            if set.contains(ele.name) {
                                set.remove(ele.name)
                            } else {
                                set.insert(ele.name)
                            }
                            preferences.allergies = Array(set)
                        }, isSelected: (preferences.allergies ?? []).contains(ele.name)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    Allergies(onboardingFlowType: .family, preferences: .constant(Preferences()))
}
