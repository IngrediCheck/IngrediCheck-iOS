//
//  SplashScreen.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/11/25.
//

import SwiftUI

struct SplashScreen: View {
    
    @State var titleArr: [String] = [
        "Know What’s Inside, Instantly",
        "Made for Your IngrediFam",
        "Shop & Eat with Confidence"
    ]
    
    @State var subTitleArr: [String] = [
        "Scan any product and get clear, simple answers, no more confusing labels.",
        "Allergies, diets, or family needs, your scans adapt to everyone you care for.",
        "Get healthier, safer alternatives without second-guessing."
    ]
    
    @State var idx: Int = 0
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Spacer()
                    Text("Skip")
                        .font(ManropeFont.medium.size(14))
                        .foregroundStyle(.grayScale110)
                }
                
                Spacer()
                Spacer()
                
                
                VStack {
                    Text(titleArr[idx])
                        .font(NunitoFont.bold.size(22))
                        .foregroundStyle(.grayScale150)
                    Text(subTitleArr[idx])
                        .font(ManropeFont.medium.size(14))
                        .foregroundStyle(.grayScale100)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                HStack {
                    
                    HStack {
                        Capsule()
                            .frame(width: idx == 0 ? 24 : 5.5, height: 5.5)
                            .foregroundStyle(
                                idx == 0
                                ? LinearGradient(colors: [Color(hex: "8DB90D"), Color(hex: "6B8E06")], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [.primary800.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                            )
                        
                        Capsule()
                            .frame(width: idx == 1 ? 24 : 5.5, height: 5.5)
                            .foregroundStyle(
                                idx == 1
                                ? LinearGradient(colors: [Color(hex: "8DB90D"), Color(hex: "6B8E06")], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [.primary800.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                            )
                        
                        Capsule()
                            .frame(width: idx == 2 ? 24 : 5.5, height: 5.5)
                            .foregroundStyle(
                                idx == 2
                                ? LinearGradient(colors: [Color(hex: "8DB90D"), Color(hex: "6B8E06")], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [.primary800.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                            )
                    }
                    
                    Spacer()
                    
                    if idx == 2 {
                        NavigationLink {
                            RootContainerView()
                        } label: {
                            GreenCapsule(title: "Get Started")
                                .frame(width: 159)
                        }
                    } else {
                        Button {
                            withAnimation(.smooth) {
                                idx = idx + 1
                            }
                        } label: {
                            GreenCircle()
                        }
                    }
                }
                .animation(.smooth, value: idx)
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    SplashScreen()
}
