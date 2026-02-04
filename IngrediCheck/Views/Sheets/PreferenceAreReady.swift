//
//  PreferenceAreReady.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct PreferenceAreReady: View {
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Microcopy.text(Microcopy.Key.Onboarding.FoodNotesReady.title)
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)

                Microcopy.text(Microcopy.Key.Onboarding.FoodNotesReady.subtitle)
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }

            GreenCapsule(title: Microcopy.string(Microcopy.Key.Common.continue))
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .overlay(
//            RoundedRectangle(cornerRadius: 4)
//                .fill(.neutral500)
//                .frame(width: 60, height: 4)
//                .padding(.top, 11)
//            , alignment: .top
//        )
        .navigationBarBackButtonHidden(true)
    }
}
