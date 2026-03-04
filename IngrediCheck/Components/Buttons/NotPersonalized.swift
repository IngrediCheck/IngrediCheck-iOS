//
//  NotPersonalized.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 26/02/26.
//

import SwiftUI

struct NotPersonalized: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .foregroundStyle(Color.grayScale100)
                .frame(width: 12.5, height: 12.5)
            
            
            Text("Not Personalized")
                .foregroundStyle(Color.grayScale100)
                .font(NunitoFont.bold.size(14))
        }
        .padding(.trailing, 16)
        .padding(.leading, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .foregroundStyle(.white)
        )
        .overlay(
            Capsule()
                .strokeBorder(lineWidth: 1)
                .foregroundStyle(.grayScale100)
        )
    }
}

#Preview {
    NotPersonalized()
}
