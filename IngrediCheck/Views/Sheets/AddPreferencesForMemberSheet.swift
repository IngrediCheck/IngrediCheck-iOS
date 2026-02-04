//
//  AddPreferencesForMemberSheet.swift
//  IngrediCheck
//
//  Created for showing "Add preferences for member?" prompt after adding a family member.
//

import SwiftUI

struct AddPreferencesForMemberSheet: View {
    var name: String
    var laterPressed: () -> Void
    var yesPressed: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text(Microcopy.formatted(Microcopy.Key.Onboarding.AddFoodNotesForMember.title, name))
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)

                Text(Microcopy.formatted(Microcopy.Key.Onboarding.AddFoodNotesForMember.subtitle, name))
                    .font(ManropeFont.medium.size(14))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                SecondaryButton(
                    title: Microcopy.string(Microcopy.Key.Common.maybeLater),
                    takeFullWidth: true,
                    action: laterPressed
                )

                Button {
                    yesPressed()
                } label: {
                    GreenCapsule(title: Microcopy.string(Microcopy.Key.Onboarding.AddFoodNotesForMember.ctaAdd))
                }
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

#Preview {
    AddPreferencesForMemberSheet(
        name: "John",
        laterPressed: {},
        yesPressed: {}
    )
}
