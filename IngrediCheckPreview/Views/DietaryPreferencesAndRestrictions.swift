//
//  DietaryPreferencesAndRestrictions.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

struct DietaryPreferencesAndRestrictions: View {
    let isFamilyFlow: Bool
    @Environment(AppNavigationCoordinator.self) private var coordinator
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.white)
                .frame(width: UIScreen.main.bounds.width * 0.9)
                .shadow(color: .gray.opacity(0.5), radius: 9, x: 0, y: 0)
        }
        .onAppear {
            coordinator.setCanvasRoute(.dietaryPreferencesAndRestrictions(isFamilyFlow: isFamilyFlow))
        }
    }
}

struct DietaryPreferencesSheetContent: View {
    let isFamilyFlow: Bool
    let letsGoPressed: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dietary 🥙 Preferences & Restrictions🍴")
                    .font(NunitoFont.semiBold.size(28))
                    .foregroundStyle(.grayScale150)
                
                Text("Let's get started with you! We'll create a profile just for you and guide you through personalized food tips.")
                    .font(ManropeFont.regular.size(14))
                    .foregroundStyle(.grayScale100)
            }
            
            if isFamilyFlow {
                HStack(spacing: -8) {
                    Image(.imageBg1)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(lineWidth: 1).foregroundStyle(Color(hex: "FFFFFF")))
                    
                    Image(.imageBg2)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(lineWidth: 1).foregroundStyle(Color(hex: "FFFFFF")))
                    
                    Image(.imageBg3)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(lineWidth: 1).foregroundStyle(Color(hex: "FFFFFF")))
                    
                    Image(.imageBg4)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(lineWidth: 1).foregroundStyle(Color(hex: "FFFFFF")))
                    
                    Image(.imageBg5)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(lineWidth: 1).foregroundStyle(Color(hex: "FFFFFF")))
                }
            }
            
//            Spacer()
            
            Button {
                letsGoPressed()
            } label: {
                GreenCapsule(title: "Let's Go!", takeFullWidth: false)
            }
            .padding(.top, 32)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
    }
}

#Preview {
    DietaryPreferencesSheetContent(isFamilyFlow: false) {
        
    }
}
