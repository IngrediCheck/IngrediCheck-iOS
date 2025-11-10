//
//  AllergySummaryCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

struct AllergySummaryCard: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                
                Text("25% Allergies")
                    .font(ManropeFont.regular.size(8))
                    .foregroundStyle(.grayScale130)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(.grayScale30, in: .capsule)
                    .overlay(
                        Capsule()
                            .stroke(lineWidth: 0.5)
                            .foregroundStyle(.grayScale70)
                    )
                
                Text("\"Your family avoids 🥜, dairy, 🦀, eggs, gluten, red meat 🥩, alcohol, making meal choices \nsimpler and \nsafer for \neveryone.\"")
                    .font(ManropeFont.bold.size(14))
                    .foregroundStyle(.grayScale140)
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 17)
            .frame(height: 196)
            
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .foregroundStyle(.grayScale10)
                    .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
            )
            
            GreenCircle(iconSize: 24, circleSize: 36)
                .frame(width: 36, height: 36)
                .padding()
        }
        
    }
}

#Preview {
    AllergySummaryCard()
}
