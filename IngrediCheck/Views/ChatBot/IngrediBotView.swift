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

            // Bot illustration
            Image("ingrediBot")
                .resizable()
                .scaledToFit()
                .frame(width: 187, height: 176)
                .rotationEffect(Angle(degrees: 10))

            // Greeting line
            (
                Microcopy.text(Microcopy.Key.Chat.IngrediBotIntro.greetingPrefix)
                    .font(NunitoFont.semiBold.size(16))
                    .foregroundStyle(.grayScale100)
                + Text(" ")
                + Microcopy.text(Microcopy.Key.Chat.IngrediBotIntro.name)
                    .font(NunitoFont.semiBold.size(16))
                    .foregroundStyle(.primary700)
            )
            .padding(.top, 4)

            // Title
            Microcopy.text(Microcopy.Key.Chat.IngrediBotIntro.title)
                .font(NunitoFont.bold.size(20))
                .multilineTextAlignment(.center)
                .foregroundStyle(.grayScale150)
                .padding(.top, 12)
                .padding(.bottom, 40)
            
            Microcopy.text(Microcopy.Key.Chat.IngrediBotIntro.question)
                .font(NunitoFont.medium.size(20))
                .foregroundStyle(.grayScale110)
                .padding(.bottom, 8)

            // Sub header
            if other {
                Group {
                    Microcopy.text(Microcopy.Key.Chat.IngrediBotIntro.OtherSelected.prefix)
                        .font(NunitoFont.regular.size(14))
                        .foregroundStyle(.grayScale110)
                         +
                         Text(" ")
                        .font(NunitoFont.regular.size(14))
                        .foregroundStyle(.grayScale110)
                         +
                         Microcopy.text(Microcopy.Key.Chat.IngrediBotIntro.OtherSelected.keyword)
                        .font(NunitoFont.bold.size(14))
                        .foregroundStyle(.grayScale140)
                         +
                         Text(" ")
                        .font(NunitoFont.regular.size(14))
                        .foregroundStyle(.grayScale110)
                         +
                         Microcopy.text(Microcopy.Key.Chat.IngrediBotIntro.OtherSelected.suffix)
                        .font(NunitoFont.regular.size(14))
                        .foregroundStyle(.grayScale110)
                }
                .multilineTextAlignment(.center)
            } else {
                Microcopy.text(Microcopy.Key.Chat.IngrediBotIntro.prompt)
                    .font(NunitoFont.regular.size(14))
                    .foregroundStyle(.grayScale110)
                    .multilineTextAlignment(.center)
            }
            

            // Action buttons
            HStack(spacing: 12) {
                SecondaryButton(
                    title: Microcopy.string(Microcopy.Key.Common.maybeLater),
                    width: 159,
                    takeFullWidth: false,
                    action: {
                        let isOnboarding = coordinator.currentCanvasRoute != .home && coordinator.currentCanvasRoute != .summaryJustMe && coordinator.currentCanvasRoute != .summaryAddFamily

                        if isOnboarding {
                            AnalyticsService.shared.trackOnboarding("Onboarding Chat Skipped", properties: [
                                "flow_type": coordinator.onboardingFlow.rawValue
                            ])
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
                    GreenCapsule(title: Microcopy.string(Microcopy.Key.Chat.IngrediBotIntro.ctaYesLetsGo), icon: nil, width: 152, height: 52)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 33)

            Microcopy.text(Microcopy.Key.Chat.IngrediBotIntro.footer)
                
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
