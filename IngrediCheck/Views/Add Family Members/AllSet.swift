//
//  AllSet.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 28/10/25.
//

import SwiftUI

struct AllSet: View {
    var body: some View {
        VStack {
            VStack(spacing: 12) {
                Microcopy.text(Microcopy.Key.Family.Setup.AddMembers.title)
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                
                Microcopy.text(Microcopy.Key.Family.Setup.AddMembers.subtitle)
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)
            
            HStack(spacing: 16) {
                Button {
                    
                } label: {
                    Text(Microcopy.string(Microcopy.Key.Common.allSet))
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .frame(width: 160, height: 52)
                        .background(
                            .grayScale40, in: RoundedRectangle(cornerRadius: 28)
                        )
                }

                
                GreenCapsule(title: Microcopy.string(Microcopy.Key.Family.Setup.AddMembers.ctaAddMember), width: 160, height: 52)
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
