//
//  DoYouHaveAnInviteCode.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct DoYouHaveAnInviteCode: View {
    let yesPressed: (() -> Void)?
    let noPressed: (() -> Void)?
    @Environment(AppNavigationCoordinator.self) private var coordinator
    
    init(yesPressed: (() -> Void)? = nil, noPressed: (() -> Void)? = nil) {
        self.yesPressed = yesPressed
        self.noPressed = noPressed
    }
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Text("Do you have an invite code?")
                        .font(NunitoFont.bold.size(22))
                        .foregroundStyle(.grayScale150)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button {
                        coordinator.navigateInBottomSheet(.alreadyHaveAnAccount)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Text("Got a family invite to IngrediFam? Enter code.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 24)

            HStack(spacing: 16) {
               
               Button {
                    yesPressed?()
                
                    } label: {
                    Text("Enter invite code")
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
                    noPressed?()
                } label: {
                    GreenCapsule(title: "No, Continue")
                }
                
            }
            .padding(.bottom, 20)

         
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarBackButtonHidden(true)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}
