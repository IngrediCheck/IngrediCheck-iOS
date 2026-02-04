//
//  AlreadyHaveAnAccount.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct AlreadyHaveAnAccount: View {
    let yesPressed: () -> Void
    let noPressed: () -> Void
    
    init(yesPressed: @escaping () -> Void = {}, noPressed: @escaping () -> Void = {}) {
        self.yesPressed = yesPressed
        self.noPressed = noPressed
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Microcopy.text(Microcopy.Key.Auth.ExistingUser.title)
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                    .padding(.bottom ,12)

                Microcopy.text(Microcopy.Key.Auth.ExistingUser.subtitleLine1)
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
                Microcopy.text(Microcopy.Key.Auth.ExistingUser.subtitleLine2)
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)

            HStack(spacing: 16) {
                SecondaryButton(
                    title: Microcopy.string(Microcopy.Key.Auth.ExistingUser.ctaYesContinue),
                    width: 152,
                    takeFullWidth: true,
                    action: yesPressed
                )

                Button {
                    noPressed()
                } label: {
                    GreenCapsule(title: Microcopy.string(Microcopy.Key.Auth.ExistingUser.ctaNoStartNew))
                }
                
            }
            .padding(.bottom, 32)

//            Text("You can switch anytime before continuing.")
//                .font(ManropeFont.regular.size(12))
//                .foregroundStyle(.grayScale120)
//                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
//        .overlay(
//            RoundedRectangle(cornerRadius: 4)
//                .fill(.neutral500)
//                .frame(width: 60, height: 4)
//                .padding(.top, 11)
//            , alignment: .top
//        )
    }
}
