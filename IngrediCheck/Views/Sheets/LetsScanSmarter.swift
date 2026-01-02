//
//  LetsScanSmarter.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct LetsScanSmarter: View {
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text("Let's scan smarter")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                
                Text("Your camera helps you quickly add products by scanning labels — it’s safe and private. We never record or share anything without your permission.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 16) {
                Button {
                    
                } label: {
                    Text("Later")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .padding(.vertical, 17)
                        .frame(maxWidth: .infinity)
                        .background(.grayScale40, in: .capsule)
                }

                
                
                GreenCapsule(title: "Enable")
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
        .navigationBarBackButtonHidden(true)
    }
}
