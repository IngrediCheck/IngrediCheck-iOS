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
                Text("Who do you grocery shop for?")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)

                Text("This helps us personalize ingredient checks for everyone.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 28)

            HStack(spacing: 16) {
                SecondaryButton(
                    title: "Just Me",
                    icon: "justMe",
                    iconWidth: 17,
                    iconHeight: 17,
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
                .accessibilityIdentifier("whos_this_for_just_me")

                SecondaryButton(
                    title: "Add Family",
                    icon: "addfamily",
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
                .accessibilityIdentifier("whos_this_for_add_family")
                
            }
            
            HStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(colors: [Color(hex: "#D6D4D4"), .white], startPoint: .trailing, endPoint: .leading)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)

                Text("Or")
                    .font(ManropeFont.medium.size(10))
                    .foregroundStyle(.grayScale120)
                    .padding(.horizontal, 7)

                Rectangle()
                    .fill(
                        LinearGradient(colors: [Color(hex: "#D6D4D4"), .white], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
            }
            .padding(.top, 14)

            Button {
                coordinator.navigateInBottomSheet(.enterInviteCode)
            } label: {
                HStack(spacing: 4) {
                    Text("Have a family invite?")
                        .font(ManropeFont.medium.size(12))
                        .foregroundStyle(.grayScale120)

                    Text("Join a Family")
                        .font(ManropeFont.bold.size(12))
                        .foregroundStyle(Color(hex: "#75990E"))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .fill(Color(hex: "#F5F5F5"))
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 52)
//        .background(.blue)
//        .overlay(
//            RoundedRectangle(cornerRadius: 4)
//                .fill(.neutral500)
//                .frame(width: 60, height: 4)
//                .padding(.top, 11)
//            , alignment: .top
//        )
    }
}

#Preview("Default") {
    WhosThisFor(
        justmePressed: {
            print("Just Me pressed")
        },
        addFamilyPressed: {
            print("Add Family pressed")
        }
    )
    .environment(AppNavigationCoordinator())
}

#Preview("Without Actions") {
    WhosThisFor()
        .environment(AppNavigationCoordinator())
}
