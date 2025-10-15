//
//  Avoid.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

struct Avoid: View {
    @State var onboardingFlowType: OnboardingFlowType
    @State var arr: [Card] = [
        Card(title: "Oils & Fats", subTitle: "In fats or oils, what do you avoid?", color: .avatarYellow, chips: [
            ChipsModel(name: "Hydrogenated oils / Trans fats", icon: "hydrogenated oil"),
            ChipsModel(name: "Canola / Seed oils", icon: "wheat"),
            ChipsModel(name: "Palm oil", icon: "palm oil"),
            ChipsModel(name: "Corn / High-frectose corn syrup", icon: "corn")
        ]),
        Card(title: "Animal-Based", subTitle: "Any animal products you don't consume?", color: .avatarPruple, chips: [
            ChipsModel(name: "Pork", icon: "pork"),
            ChipsModel(name: "Beef", icon: "beef"),
            ChipsModel(name: "Honey", icon: "honey"),
            ChipsModel(name: "Gelatin / Rennet", icon: "gelatin"),
            ChipsModel(name: "Shellfish", icon: "shellfish"),
            ChipsModel(name: "Insects", icon: "insects"),
            ChipsModel(name: "Seafood (fish)", icon: "fish"),
            ChipsModel(name: "Lard / Animal fat", icon: "lard")
        ]),
        Card(title: "Stimulants & Substances", subTitle: "Do you avoid these?", color: .avatarGreen, chips: [
            ChipsModel(name: "Alcohol", icon: "histamine"),
            ChipsModel(name: "Caffeine", icon: "caffeine")
        ]),
        Card(title: "Additives & Sweeteners", subTitle: "Do you stay away from processed ingredients?", color: .avatarOrange, chips: [
            ChipsModel(name: "MSG", icon: "msg"),
            ChipsModel(name: "Artificial sweeteners", icon: "artificial sweeteners"),
            ChipsModel(name: "Preservatives", icon: "gelatin"),
            ChipsModel(name: "Refined sugar", icon: "refined sugar"),
            ChipsModel(name: "Corn syrup / HFCS", icon: "corn"),
            ChipsModel(name: "Stevia ? Monk fruit", icon: "stevia"),
        ]),
        Card(title: "Plant-Based Restrictions", subTitle: "Any plant foods you avoid?", color: .avatarGreen, chips: [
            ChipsModel(name: "Nightshades (paprika, pappers, etc.)", icon: "nightshades"),
            ChipsModel(name: "Garlic / Onion", icon: "fodmap")
        ])
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                
                if onboardingFlowType == .individual {
                    onboardingSheetTitle(title: "Anything you avoid in your diet?")
                } else {
                    onboardingSheetTitle(title: "Anything your IngrediFam avoids?")
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
    Avoid(onboardingFlowType: .individual)
}
