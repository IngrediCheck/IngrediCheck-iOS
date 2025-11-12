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

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Start at top-left
        path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
        
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        
        // Right edge (down to bottom-right corner start)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cutoutRadius))
        
        // Bottom-right inward curve (circle-like cutout)
        path.addRelativeArc(
            center: CGPoint(x: rect.maxX - cutoutRadius, y: rect.maxY - cutoutRadius),
            radius: cutoutRadius,
            startAngle: .degrees(0),
            delta: .degrees(90)
        )
        
        // Bottom edge to bottom-left corner
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        
        // Left edge up to top-left
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}

#Preview {
    CustomRoundedRectangle(cornerRadius: 24, cutoutRadius: 100)
        .fill(Color.green.opacity(0.3))
        .frame(width: 200, height: 150)
}
