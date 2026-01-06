//
//  WouldYouLikeToInvite.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct WouldYouLikeToInvite: View {
    var name: String
    var invitePressed: () -> Void = { }
    var continuePressed: () -> Void = { }
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text("Would you like to invite \(name) to join IngrediFam?")
                    .font(NunitoFont.bold.size(20))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                
                Text("No worries if you skip this step. You can share the code with \(name) later too.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            HStack(spacing: 16) {
                Button {
                    continuePressed()
                } label: {
                    Text("Maybe later")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .padding(.vertical, 17)
                        .frame(maxWidth: .infinity)
                        .background(.grayScale40, in: .capsule)
                }
                Button {
                    invitePressed()
                } label: {
                    GreenCapsule(title: "Invite" , icon: "share" ,iconWidth: 12 , iconHeight: 12 ,)
                }
                
               

                
            }
            .padding(.horizontal, 20)
        }
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
