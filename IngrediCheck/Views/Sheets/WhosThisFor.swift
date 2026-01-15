//
//  WhosThisFor.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct WhosThisFor: View {
    let justmePressed: (() -> Void)?
    let addFamilyPressed: (() -> Void)?
    @Environment(AppNavigationCoordinator.self) private var coordinator
    
    init(justmePressed: (() -> Void)? = nil, addFamilyPressed: (() -> Void)? = nil) {
        self.justmePressed = justmePressed
        self.addFamilyPressed = addFamilyPressed
    }
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Text("Hey there! Who’s this for?")
                        .font(NunitoFont.bold.size(22))
                        .foregroundStyle(.grayScale150)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button {
                        coordinator.navigateInBottomSheet(.doYouHaveAnInviteCode)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Text("Is it just you, or your whole IngrediFam — family, friends, anyone you care about?")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)

            HStack(spacing: 16) {
                SecondaryButton(
                    title: "Just Me",
                    takeFullWidth: true,
                    action: { justmePressed?() }
                )

                SecondaryButton(
                    title: "Add Family",
                    takeFullWidth: true,
                    action: { addFamilyPressed?() }
                )
                
            }
            .padding(.bottom, 20)

            Text("You can always add or edit members later.")
                .font(ManropeFont.regular.size(12))
                .foregroundStyle(.grayScale90)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .overlay(
//            RoundedRectangle(cornerRadius: 4)
//                .fill(.neutral500)
//                .frame(width: 60, height: 4)
//                .padding(.top, 11)
//            , alignment: .top
//        )
    }
}
