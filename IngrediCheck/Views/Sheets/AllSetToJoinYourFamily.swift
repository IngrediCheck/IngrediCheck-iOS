//
//  AllSetToJoinYourFamily.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct AllSetToJoinYourFamily: View {
    let goToHomePressed: () -> Void
    
    init(goToHomePressed: @escaping () -> Void = {}) {
        self.goToHomePressed = goToHomePressed
    }
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Microcopy.text(Microcopy.Key.Onboarding.JoinFamilyReady.title)
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                    .padding(.bottom , 12)

                Microcopy.text(Microcopy.Key.Onboarding.JoinFamilyReady.subtitle)
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)

            Button {
                goToHomePressed()
            } label: {
                GreenCapsule(title: Microcopy.string(Microcopy.Key.Common.goToHome))
                    .frame(width: 156)
            }
            
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}
