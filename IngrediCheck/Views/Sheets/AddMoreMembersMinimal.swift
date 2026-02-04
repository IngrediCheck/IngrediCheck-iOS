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
                Microcopy.text(Microcopy.Key.Family.Setup.AddMembers.title)
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                
                Microcopy.text(Microcopy.Key.Family.Setup.AddMembers.subtitle)
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            HStack(spacing: 16) {
                SecondaryButton(
                    title: Microcopy.string(Microcopy.Key.Common.allSet),
                    takeFullWidth: true,
                    action: allSetPressed
                )
                
                Button {
                    addMorePressed()
                } label: {
                    GreenCapsule(title: Microcopy.string(Microcopy.Key.Family.Setup.AddMembers.ctaAddMember))
                }

                
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
        .background(.white)
//        .overlay(
//            RoundedRectangle(cornerRadius: 4)
//                .fill(.neutral500)
//                .frame(width: 60, height: 4)
//                .padding(.top, 11)
//            , alignment: .top
//        )
    }
}

#Preview {
    AddMoreMembersMinimal {
        
    } addMorePressed: {
        
    }
}
