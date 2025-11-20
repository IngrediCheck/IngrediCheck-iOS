//
//  Temp4.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 12/11/25.
//

import SwiftUI

struct CustomRoundedRectangle: Shape {
    var cornerRadius: CGFloat = 24
    var cutoutRadius: CGFloat = 40
    
    // Animate changes to either radius smoothly
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerRadius, cutoutRadius) }
        set {
            cornerRadius = newValue.first
            cutoutRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Clamp radii to safe values
        let cr = max(0, min(cornerRadius, min(rect.width, rect.height) / 2))
        let cutR = max(0, min(cutoutRadius, min(rect.width, rect.height) / 2))

        // Start at top-left
        path.move(to: CGPoint(x: rect.minX + cr, y: rect.minY))

        // Top edge and top-right rounded corner
        path.addLine(to: CGPoint(x: rect.maxX - cr, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + cr),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )

        if cutR > 0 {
            // Right edge down to the start of the inward cutout
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cutR))

            // Inward circular cutout at bottom-right (quarter circle, clockwise)
            path.addRelativeArc(
                center: CGPoint(x: rect.maxX - cutR, y: rect.maxY - cutR),
                radius: cutR,
                startAngle: .degrees(0),
                delta: .degrees(-90)
            )
        } else {
            // Regular bottom-right rounded corner when cutout is disabled
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cr))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - cr, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
        }

        // Bottom edge and bottom-left rounded corner
        path.addLine(to: CGPoint(x: rect.minX + cr, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - cr),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        // Left edge and top-left rounded corner
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cr))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + cr, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}

#Preview {
    CustomRoundedRectangle(cornerRadius: 24, cutoutRadius: 40)
        .fill(Color.green.opacity(0.3))
        .frame(width: 240, height: 180)
}
