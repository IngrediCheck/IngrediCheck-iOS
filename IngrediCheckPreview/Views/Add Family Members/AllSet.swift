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
                Text("Add more members?")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                
                Text("Start by adding their name and a fun avatar—it’ll help us personalize food tips just for them.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)
            
            HStack(spacing: 16) {
                Button {
                    
                } label: {
                    Text("All Set!")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .frame(width: 160, height: 52)
                        .background(
                            .grayScale40, in: RoundedRectangle(cornerRadius: 28)
                        )
                }

                
                GreenCapsule(title: "Add Member", width: 160, height: 52)
            }
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
