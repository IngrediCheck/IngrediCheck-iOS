//
//  MainCanvasView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

enum mainCanvasViewSheetOptions: String, Identifiable {
    case allergies
    case intollerances
    case healthConditions
    case lifestage
    case region
    case avoid
    case lifestyle
    case nutrition
    case ethical
    case taste


    var id: String {
        return self.rawValue
    }
}

struct MainCanvasView: View {
    
    @StateObject var store = Onboarding(onboardingFlowtype: .individual)
    
    var body: some View {
        ZStack {
            
            
            
            VStack(spacing: 0) {
                CustomIngrediCheckProgressBar()
                
                CanvasTagBar()
                    .padding(.bottom, 16)
                
                
                RoundedRectangle(cornerRadius: 24)
                    .foregroundStyle(.white)
                    .shadow(color: .gray.opacity(0.3), radius: 9, x: 0, y: 0)
                    .frame(width: UIScreen.main.bounds.width * 0.9)
            }
            
        }
    }
}

func onboardingSheetTitle(title: String) -> some View {
    Group {
        (Text("Q. ")
            .font(ManropeFont.bold.size(20))
            .foregroundStyle(.grayScale70)
        +
        Text(title)
            .font(NunitoFont.bold.size(20))
            .foregroundStyle(.grayScale150))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

func onboardingSheetSubtitle(subtitle: String, onboardingFlowType: OnboardingFlowType) -> some View {
    if onboardingFlowType == .individual {
        Text(subtitle)
            .font(ManropeFont.regular.size(14))
            .foregroundStyle(.grayScale100)
    } else {
        Text(subtitle)
            .font(ManropeFont.regular.size(14))
            .foregroundStyle(.grayScale120)
    }
}

func onboardingSheetFamilyMemberSelectNote() -> some View {
    HStack(alignment: .center, spacing: 0) {
        
        Image(.yellowBulb)
            .resizable()
            .frame(width: 22, height: 26)
        
        Text("Select members one by one to personalize their choices.")
            .font(ManropeFont.regular.size(12))
            .foregroundStyle(.grayScale100)
    }
}

#Preview {
    MainCanvasView()
}
