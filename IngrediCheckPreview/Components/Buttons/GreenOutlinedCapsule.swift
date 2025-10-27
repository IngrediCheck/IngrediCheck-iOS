//
//  GreenOutlinedCapsule.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 17/10/25.
//

import SwiftUI

struct GreenOutlinedCapsule: View {
    var image: String
    var title: String
    var width: CGFloat? = 160
    var height: CGFloat? = 52
    var body: some View {
        Button {
            
        } label: {
            HStack(spacing: 10) {
                Image(image)
                Text(title)
                    .font(NunitoFont.semiBold.size(16))
                    .foregroundStyle(rotatedGradient(colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")], angle: 88))
            }
            .frame(width: width, height: height)
            .background(
                Capsule()
                    .stroke(lineWidth: 1.5)
                    .foregroundStyle(rotatedGradient(colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")], angle: 85))
            )
        }
        
    }
}

#Preview {
    GreenOutlinedCapsule(image: "stars-generate", title: "Generate")
}

func rotatedGradient(colors: [Color], angle: Double) -> LinearGradient {
    // Convert angle to a unit vector
    let rad = angle * .pi / 180
    let x = 0.5 + 0.5 * cos(rad)
    let y = 0.5 + 0.5 * sin(rad)
    
    return LinearGradient(
        gradient: Gradient(colors: colors),
        startPoint: UnitPoint(x: 0.5 - (x - 0.5), y: 0.5 - (y - 0.5)),
        endPoint: UnitPoint(x: x, y: y)
    )
}

