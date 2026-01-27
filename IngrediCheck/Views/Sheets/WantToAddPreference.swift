//
//  WantToAddPreference.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct WantToAddPreference: View {
    var name: String
    var laterPressed: () -> Void = { }
    var yesPressed: () -> Void = { }
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text("Do you want to add preferences for \(name)?")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                
                Text("Don't worry, \(name) can add or edit her preferences once she joins Ingredifam")
                    .font(ManropeFont.medium.size(14))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
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
