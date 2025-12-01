//
//  LifestyleAndChoicesCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 08/10/25.
//

import SwiftUI

struct LifestyleAndChoicesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lifestyle & Choices")
                    .font(ManropeFont.medium.size(18))
                    .foregroundStyle(.grayScale150)
                    .fixedSize(horizontal: false, vertical: true) // let it wrap
                    .lineLimit(nil)
                
                Text("A quick look at your family's food value.")
                    .font(ManropeFont.regular.size(12))
                    .foregroundStyle(.grayScale130)
                    .fixedSize(horizontal: false, vertical: true) // let it wrap
                    .lineLimit(nil)
            }
            .padding(.bottom, 8)
            
            Text("Your family leans Vegetarian.\nAlso values Organic & Seasonal Eating.")
                .font(ManropeFont.regular.size(14))
                .foregroundStyle(.grayScale100)
            
            
            HStack {
                Spacer()
                Image("leaf")
            }
            .padding(.top, 20)
        }
        .padding(12)
        .frame(height: 268)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(.grayScale10)
                .shadow(color: Color(hex: "#ECECEC"), radius: 9, x: 0, y: 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(lineWidth: 0.25)
                .foregroundStyle(.grayScale60)
        )
    }
}

#Preview {
    LifestyleAndChoicesCard()
}
