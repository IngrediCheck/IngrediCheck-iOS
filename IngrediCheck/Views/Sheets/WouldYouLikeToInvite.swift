//
//  WouldYouLikeToInvite.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct WouldYouLikeToInvite: View {
    var name: String
    var isLoading: Bool = false
    var invitePressed: () -> Void = { }
    var continuePressed: () -> Void = { }
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text(Microcopy.formatted(Microcopy.Key.Family.InvitePrompt.title, name))
                    .font(NunitoFont.bold.size(20))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                
                Text(Microcopy.formatted(Microcopy.Key.Family.InvitePrompt.subtitle, name))
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            HStack(spacing: 16) {
                SecondaryButton(
                    title: Microcopy.string(Microcopy.Key.Common.maybeLater),
                    takeFullWidth: true,
                    isDisabled: isLoading,
                    action: continuePressed
                )
                
                Button {
                    invitePressed()
                } label: {
                    ZStack {
                        GreenCapsule(title: Microcopy.string(Microcopy.Key.Common.invite), icon: "share" ,iconWidth: 12 , iconHeight: 12 ,)
                            .opacity(isLoading ? 0.6 : 1)

                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                }
                .disabled(isLoading)
                
               

                
            }
            .padding(.horizontal, 20)
        }
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
