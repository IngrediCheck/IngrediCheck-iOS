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
                    .fill(
                        .primary800
                        .shadow(
                            .drop(color: Color(hex: "C5C5C5").opacity(0.57), radius: 11, x: 0, y: 4)
                        )
                        .shadow(
                            .inner(color: Color(hex: "DAFF67").opacity(0.25), radius: 7.3, x: 2, y: 9)
                        )
                        .shadow(
                            .inner(color: Color(hex: "A2D20C"), radius: 5.7, x: 0, y: 4)
                        )
                        
                    )
                    .frame(width: circleSize, height: circleSize)
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
