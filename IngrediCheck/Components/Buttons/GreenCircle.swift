//
//  GreenCircle.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 09/10/25.
//

import SwiftUI

struct GreenCircle: View {
    
    var iconName: String = "right-arrow-rounded-edge"
    var iconSize: CGFloat = 32
    var circleSize: CGFloat = 52
    
    var body: some View {
        Image(iconName)
            .resizable()
            .frame(width: iconSize, height: iconSize)
            .padding(10)
            .background(
                Capsule()
                    .frame(width: circleSize, height: circleSize)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .shadow(
                            .drop(color: Color(hex: "C5C5C5").opacity(0.57), radius: 11, x: 0, y: 4)
                        )
                        .shadow(
                            .inner(color: Color(hex: "EDEDED").opacity(0.25), radius: 7.5, x: 2, y: 4)
                        )
                        .shadow(
                            .inner(color: Color(hex: "72930A"), radius: 5.7, x: 0, y: 4)
                        )
                        
                    )
                    .rotationEffect(.degrees(17))
                    .overlay(
                        Circle()
                            .stroke(lineWidth: 1)
                            .foregroundColor(Color(hex: "FFFFFF"))
                    )
            )
    }
}

#Preview {
    GreenCircle()
}
