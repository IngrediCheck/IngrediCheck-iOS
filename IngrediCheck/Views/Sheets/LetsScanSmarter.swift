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
                Microcopy.text(Microcopy.Key.Permissions.LetsScanSmarter.title)
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                
                Microcopy.text(Microcopy.Key.Permissions.LetsScanSmarter.subtitle)
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 16) {
                SecondaryButton(
                    title: Microcopy.string(Microcopy.Key.Common.notNow),
                    takeFullWidth: true,
                    action: {}
                )

                
                
                GreenCapsule(title: Microcopy.string(Microcopy.Key.Common.enable))
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
