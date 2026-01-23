//
//  IngrediBotView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 30/10/25.
//

import SwiftUI

struct IngrediBotView: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @State var other: Bool = true
    var body: some View {
        VStack(spacing: 0) {
            
            Spacer()
            
            // Bot illustration
            Image("ingrediBot")
                .resizable()
                .scaledToFit()
                .frame(width: 187, height: 176)
                .rotationEffect(Angle(degrees: 10))

            // Greeting line
            (
                Text("Hey! 👋 I'm ")
                    .font(NunitoFont.semiBold.size(16))
                    .foregroundStyle(.grayScale100)
                + Text("IngrediBot,")
                    .font(NunitoFont.semiBold.size(16))
                    .foregroundStyle(.primary700)
            )
            .padding(.top, 4)

            // Title
            Text("How about making food choices easier together?")
                .font(NunitoFont.bold.size(20))
                .multilineTextAlignment(.center)
                .foregroundStyle(.grayScale150)
                .padding(.top, 12)
                .padding(.bottom, 40)
            
            Text("Shall we get started?")
                .font(NunitoFont.medium.size(20))
                .foregroundStyle(.grayScale110)
                .padding(.bottom, 8)

            // Sub header
            if other {
                Group {
                    Text("I noticed you selected")
                        .font(NunitoFont.regular.size(14))
                        .foregroundStyle(.grayScale110)
                         +
                         Text(" \"Other\" ")
                        .font(NunitoFont.bold.size(14))
                        .foregroundStyle(.grayScale140)
                         +
                         Text("earlier, that's great!\nCould you tell me a bit more about it?")
                        .font(NunitoFont.regular.size(14))
                        .foregroundStyle(.grayScale110)
                }
                .multilineTextAlignment(.center)
            } else {
                Text("\"Tell me a bit about what kind of food experience you'd love here.\"")
                    .font(NunitoFont.regular.size(14))
                    .foregroundStyle(.grayScale110)
                    .multilineTextAlignment(.center)
            }
            

            // Action buttons
            HStack(spacing: 12) {
                SecondaryButton(
                    title: "Maybe later",
                    width: 159,
                    takeFullWidth: false,
                    action: {
                        let isOnboarding = coordinator.currentCanvasRoute != .home && coordinator.currentCanvasRoute != .summaryJustMe && coordinator.currentCanvasRoute != .summaryAddFamily
                        
                        if isOnboarding {
                            if coordinator.onboardingFlow == .individual {
                                coordinator.showCanvas(.summaryJustMe)
                            } else {
                                coordinator.showCanvas(.summaryAddFamily)
                            }
                        } else {
                            coordinator.navigateInBottomSheet(.homeDefault)
                        }
                    }
                )

                Button {
                    coordinator.navigateInBottomSheet(.chatConversation)
                } label: {
                    GreenCapsule(title: "Yes, let's go", icon: nil, width: 152, height: 52)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 33)

            Text("No problem! You can come back anytime — I'll be here when you're ready.")
                
                .font(ManropeFont.regular.size(12))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: "B6B6B6"))
                .padding(.top, 13)
                .padding(.horizontal, -2)
                .padding(.horizontal, 1)
                .padding(.bottom, 32	)
                

            
        }
        .padding(.horizontal, 20)
        
    }
}

#Preview("Default") {
    IngrediBotView()
        .environment(AppNavigationCoordinator())
}

#Preview("Other Selected") {
    IngrediBotView(other: true)
        .environment(AppNavigationCoordinator())
}

#Preview("Other Not Selected") {
    IngrediBotView(other: false)
        .environment(AppNavigationCoordinator())
}
