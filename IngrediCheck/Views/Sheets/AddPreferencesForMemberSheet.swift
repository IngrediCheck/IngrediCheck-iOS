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
                Text("Do you want to add foodnote for \(name)?")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)

                Text("Don't worry, \(name) can add or edit their foodnote once they join IngrediFam")
                    .font(ManropeFont.medium.size(14))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                SecondaryButton(
                    title: "Later",
                    takeFullWidth: true,
                    action: laterPressed
                )

                Button {
                    yesPressed()
                } label: {
                    GreenCapsule(title: "Yes")
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
