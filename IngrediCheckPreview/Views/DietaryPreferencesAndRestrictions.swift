//
//  DietaryPreferencesAndRestrictions.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

struct DietaryPreferencesAndRestrictions: View {
    @State var isFamilyFlow: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Dietary 🥙 Preferences & Restrictions🍴")
                    .font(NunitoFont.semiBold.size(32))
                    .foregroundStyle(.grayScale150)
                
                Text("Let’s get started with you! We’ll create a profile just for you and guide you through personalized food tips.")
                    .font(ManropeFont.regular.size(14))
                    .foregroundStyle(.grayScale100)
            }
            
            if isFamilyFlow {
                HStack(spacing: -8) {
                    Image(.imageBg1)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(lineWidth: 1)
                                .foregroundStyle(Color(hex: "FFFFFF"))
                        )
                    
                    Image(.imageBg2)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(lineWidth: 1)
                                .foregroundStyle(Color(hex: "FFFFFF"))
                        )
                    
                    Image(.imageBg3)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(lineWidth: 1)
                                .foregroundStyle(Color(hex: "FFFFFF"))
                        )
                    
                    Image(.imageBg4)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(lineWidth: 1)
                                .foregroundStyle(Color(hex: "FFFFFF"))
                        )
                    
                    Image(.imageBg5)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(lineWidth: 1)
                                .foregroundStyle(Color(hex: "FFFFFF"))
                        )
                }
                .padding(.top, 20)
            }
            
            NavigationLink {
                MainCanvasView(flow: isFamilyFlow ? .family : .individual)
            } label: {
                GreenCapsule(title: "Let's Go!", takeFullWidth: false)
                    .padding(.top, 60)
            }

            
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    DietaryPreferencesAndRestrictions()
}
