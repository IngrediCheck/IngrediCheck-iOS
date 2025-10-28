//
//  MeetYourIngrediFam.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 28/10/25.
//

import SwiftUI

struct MeetYourIngrediFam: View {
    var body: some View {
        VStack(spacing: 20) {
            Image("IngrediFamGroup")
                .resizable()
                .frame(width: 295, height: 146)
            
            VStack(spacing: 16) {
                Text("Let's meet your IngrediFam!")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                
                Text("Add everyone’s name and a fun avatar so we can tailor tips and scans just for them.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
                
                
                GreenCapsule(title: "Add Members")
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
    }
}
