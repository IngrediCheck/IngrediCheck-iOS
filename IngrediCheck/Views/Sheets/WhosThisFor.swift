//
//  WhosThisFor.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct WhosThisFor: View {
    let justmePressed: (() async -> Void)?
    let addFamilyPressed: (() async -> Void)?
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @State private var isJustMeLoading = false
    @State private var isAddFamilyLoading = false
    
    init(justmePressed: (() async -> Void)? = nil, addFamilyPressed: (() async -> Void)? = nil) {
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
                    isLoading: isJustMeLoading,
                    isDisabled: isJustMeLoading || isAddFamilyLoading,
                    action: {
                        guard !isJustMeLoading else { return }
                        Task {
                            isJustMeLoading = true
                            await justmePressed?()
                            // Reset loading state after operation completes
                            // Add a small delay to ensure navigation completes
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            await MainActor.run {
                                isJustMeLoading = false
                            }
                        }
                    }
                )

                SecondaryButton(
                    title: "Add Family",
                    takeFullWidth: true,
                    isLoading: isAddFamilyLoading,
                    isDisabled: isJustMeLoading || isAddFamilyLoading,
                    action: {
                        guard !isAddFamilyLoading else { return }
                        Task {
                            isAddFamilyLoading = true
                            await addFamilyPressed?()
                            // Reset loading state after operation completes
                            // Add a small delay to ensure navigation completes
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            await MainActor.run {
                                isAddFamilyLoading = false
                            }
                        }
                    }
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
