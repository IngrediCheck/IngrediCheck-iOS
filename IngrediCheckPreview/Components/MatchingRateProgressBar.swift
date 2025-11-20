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
    var cornerRadius: CGFloat = 4

    // Convenience init to specify full angular width (in radians)
    init(angle: Double,
         width: Double,
         innerRadius: CGFloat,
         outerRadius: CGFloat,
         cornerRadius: CGFloat = 4) {
        self.angle = angle
        self.halfWidth = width / 2
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.cornerRadius = cornerRadius
    }

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

        // Helper to ensure radius fits available edge lengths
        func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            let dx = a.x - b.x
            let dy = a.y - b.y
            return sqrt(dx * dx + dy * dy)
        }

        // Clamp per-corner radius to avoid self-intersection on very small sides
        let r1 = min(cornerRadius, 0.5 * min(distance(innerLeft, outerLeft), distance(outerLeft, outerRight))) // at outerLeft
        let r2 = min(cornerRadius, 0.5 * min(distance(outerLeft, outerRight), distance(outerRight, innerRight))) // at outerRight
        let r3 = min(cornerRadius, 0.5 * min(distance(outerRight, innerRight), distance(innerRight, innerLeft))) // at innerRight
        let r4 = min(cornerRadius, 0.5 * min(distance(innerRight, innerLeft), distance(innerLeft, outerLeft))) // at innerLeft

        // Draw rounded quadrilateral using tangent arcs at each corner
        path.move(to: innerLeft)
        path.addArc(tangent1End: outerLeft, tangent2End: outerRight, radius: r4)
        path.addArc(tangent1End: outerRight, tangent2End: innerRight, radius: r1)
        path.addArc(tangent1End: innerRight, tangent2End: innerLeft, radius: r2)
        path.addArc(tangent1End: innerLeft, tangent2End: outerLeft, radius: r3)
        path.closeSubpath()

        return path
    }
}

struct MatchingRateProgressBar: View {
    let totalSegments = 12
    var filledSegments = 7
    let innerRadius: CGFloat = 74
    let outerRadius: CGFloat = 130
    let segmentWidthFactor: Double = 0.88 // 0..1 of the per-segment angle

    var body: some View {
        ZStack {
            ForEach(0..<totalSegments, id: \.self) { i in
                // compute center angle for this segment across 180 degrees
                let angle = Double(i) * Double.pi / Double(totalSegments - 1) - Double.pi / 2
                // fullWidth controls how wide the wedge is; tweak factor for spacing
                let fullWidth = (Double.pi / Double(totalSegments - 1)) * segmentWidthFactor

                let isFilled = i < filledSegments

                TaperedBar(angle: angle,
                           width: fullWidth,
                           innerRadius: innerRadius,
                           outerRadius: outerRadius,
                           cornerRadius: 4)
                .fill(isFilled ? .secondary800 : .grayScale30)
            }
        }
        .frame(width: 360, height: 220)
        .rotationEffect(.degrees(-90))
    }
}

struct PreviewProvider_Previews: PreviewProvider {
    static var previews: some View {
        MatchingRateProgressBar()
    }
}




