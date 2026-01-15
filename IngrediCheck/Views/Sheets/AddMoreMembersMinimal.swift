//
//  AddMoreMembersMinimal.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct AddMoreMembersMinimal: View {
    let allSetPressed: () -> Void
    let addMorePressed: () -> Void
    
    init(allSetPressed: @escaping () -> Void = {}, addMorePressed: @escaping () -> Void = {}) {
        self.allSetPressed = allSetPressed
        self.addMorePressed = addMorePressed
    }
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text("Add more members?")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                
                Text("Start by adding their name and a fun avatar—it’ll help us personalize food tips just for them.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            HStack(spacing: 16) {
                SecondaryButton(
                    title: "All Set!",
                    takeFullWidth: true,
                    action: allSetPressed
                )
                
                Button {
                    addMorePressed()
                } label: {
                    GreenCapsule(title: "Add Member")
                }

                
            }
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
    }
}
