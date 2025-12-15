//
//  GreenOutlinedCapsule.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 17/10/25.
//

import SwiftUI

struct GreenOutlinedCapsule: View {
    var image: String? = nil
    var title: String
    var width: CGFloat? = 152
    var height: CGFloat? = 52
    var body: some View {
        HStack(spacing: 10) {
            if let image = image {
                Image(image)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(rotatedGradient(colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")], angle: 88))
            }
            Text(title)
                .font(NunitoFont.semiBold.size(16))
                .foregroundStyle(rotatedGradient(colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")], angle: 88))
        }
        .frame(height: height)
        .frame(minWidth: 152)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(Color.white)
        )
        .overlay(
            Capsule()
                .stroke(lineWidth: 1.5)
                .foregroundStyle(rotatedGradient(colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")], angle: 85))
        )
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

