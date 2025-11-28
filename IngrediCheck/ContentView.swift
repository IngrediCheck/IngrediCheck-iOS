//
//  ContentView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import SwiftUI

struct HomeCardShape: Shape {

    var radius: CGFloat = 24            // normal corners
    var inwardRadius: CGFloat = 42      // deeper inside curve

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Start → top-left that is already rounded
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))

        // Top edge → top-right outer-rounded
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )

        // Right edge (stop before inward curve)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - inwardRadius))

        // ⤵️ **Bottom-right inward curve**
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - inwardRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )

        // Bottom edge → bottom-left corner
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        // Left edge → top-left outer curve
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        return path
    }
}

struct MyIcon2: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.addRect(CGRect(x: 0.00782*width, y: 0.01848*height, width: 0.98436*width, height: 0.96304*height))
        return path
    }
}

#Preview {
    MyIcon2()
}

