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
                Text("Are you an existing user?")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                    .padding(.bottom ,12)

                Text("Have you used IngrediCheck earlier? If yes, continue. ")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
                Text("If not, start new.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)

            HStack(spacing: 16) {
                Button {
                    yesPressed()
                } label: {
                    Text("Yes, continue")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .frame(height: 52)
                        .frame(minWidth: 152)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule()
                                .foregroundStyle(.grayScale40)
                        )
                }

                Button {
                    noPressed()
                } label: {
                    GreenCapsule(title: "No, start new")
                }
                
            }
            .padding(.bottom, 32)

//            Text("You can switch anytime before continuing.")
//                .font(ManropeFont.regular.size(12))
//                .foregroundStyle(.grayScale120)
//                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}
