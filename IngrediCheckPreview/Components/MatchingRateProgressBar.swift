//
//  MatchingRateProgressBar.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/10/25.
//

import SwiftUI

// Tapered wedge-like bar (narrow inner edge, wider outer edge)
struct TaperedBar: Shape {
    // angle: center angle in radians
    // halfWidth: how wide the wedge is (in radians)
    var angle: Double
    var halfWidth: Double
    var innerRadius: CGFloat
    var outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let start = angle - halfWidth
        let end = angle + halfWidth

        // compute positions; convert trig (Double) -> CGFloat
        let innerLeft = CGPoint(
            x: center.x + CGFloat(cos(start)) * innerRadius,
            y: center.y + CGFloat(sin(start)) * innerRadius
        )
        let innerRight = CGPoint(
            x: center.x + CGFloat(cos(end)) * innerRadius,
            y: center.y + CGFloat(sin(end)) * innerRadius
        )
        let outerLeft = CGPoint(
            x: center.x + CGFloat(cos(start)) * outerRadius,
            y: center.y + CGFloat(sin(start)) * outerRadius
        )
        let outerRight = CGPoint(
            x: center.x + CGFloat(cos(end)) * outerRadius,
            y: center.y + CGFloat(sin(end)) * outerRadius
        )

        path.move(to: innerLeft)
        path.addLine(to: outerLeft)
        path.addLine(to: outerRight)
        path.addLine(to: innerRight)
        path.closeSubpath()

        return path
    }
}

struct TaperedGaugeView: View {
    let totalSegments = 12
    let filledSegments = 1
    let innerRadius: CGFloat = 60
    let outerRadius: CGFloat = 120

    var body: some View {
        ZStack {
            ForEach(0..<totalSegments, id: \.self) { i in
                // compute center angle for this segment across 180 degrees
                let angle = Double(i) * Double.pi / Double(totalSegments - 1) - Double.pi / 2
                // halfWidth controls how wide the wedge is; tweak multiplier for spacing
                let halfWidth = (Double.pi / Double(totalSegments - 1)) * 0.4

                let isFilled = i < filledSegments

                TaperedBar(angle: angle,
                           halfWidth: halfWidth,
                           innerRadius: innerRadius,
                           outerRadius: outerRadius
                )
                    .fill(isFilled ? Color.orange : Color.gray.opacity(0.18))
            }

            VStack(spacing: 4) {
                Text("140%")
                    .font(.system(size: 44, weight: .bold))
                Text("Matched")
                    .foregroundColor(.gray)
                    .font(.system(size: 18, weight: .medium))
            }
            .offset(y: 30)
        }
        .frame(width: 360, height: 220)
    }
}

struct PreviewProvider_Previews: PreviewProvider {
    static var previews: some View {
        TaperedGaugeView()
    }
}




