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
    enum Mode {
        case single(filledSegments: Int)
        case breakdown(matchedCount: Int, uncertainCount: Int, unmatchedCount: Int)
    }

    enum SegmentKind: Hashable {
        case matched
        case uncertain
        case unmatched
    }

    let totalSegments: Int
    let mode: Mode

    @State private var selectedKind: SegmentKind?

    let innerRadius: CGFloat = 74
    let outerRadius: CGFloat = 130
    let segmentWidthFactor: Double = 0.88 // 0..1 of the per-segment angle

    init(filledSegments: Int = 7, totalSegments: Int = 12) {
        self.totalSegments = totalSegments
        self.mode = .single(filledSegments: filledSegments)
    }

    init(matchedCount: Int, uncertainCount: Int, unmatchedCount: Int, totalSegments: Int = 12) {
        self.totalSegments = totalSegments
        self.mode = .breakdown(
            matchedCount: matchedCount,
            uncertainCount: uncertainCount,
            unmatchedCount: unmatchedCount
        )
    }

    private var matchedColor: Color { Color(hex: "#82B611") }
    private var uncertainColor: Color { Color(hex: "#FFBE18") }
    private var unmatchedColor: Color { Color(hex: "#FF1606") }

    private func segmentsForBreakdown(matched: Int, uncertain: Int, unmatched: Int) -> [SegmentKind]? {
        let total = matched + uncertain + unmatched
        if total <= 0 {
            return nil
        }

        let counts: [(SegmentKind, Int)] = [(.matched, matched), (.uncertain, uncertain), (.unmatched, unmatched)]

        let raw: [(SegmentKind, Double)] = counts.map { kind, count in
            (kind, (Double(count) / Double(total)) * Double(totalSegments))
        }

        var base: [SegmentKind: Int] = Dictionary(uniqueKeysWithValues: raw.map { ($0.0, Int(floor($0.1))) })
        var used = base.values.reduce(0, +)
        var remainder = max(0, totalSegments - used)

        let fractionalSorted = raw
            .map { (kind: $0.0, frac: $0.1 - floor($0.1)) }
            .sorted { a, b in
                if a.frac == b.frac {
                    return String(describing: a.kind) < String(describing: b.kind)
                }
                return a.frac > b.frac
            }

        var idx = 0
        while remainder > 0 && !fractionalSorted.isEmpty {
            let kind = fractionalSorted[idx % fractionalSorted.count].kind
            base[kind, default: 0] += 1
            used += 1
            remainder -= 1
            idx += 1
        }

        var result: [SegmentKind] = []
        result.reserveCapacity(totalSegments)
        result.append(contentsOf: Array(repeating: .matched, count: base[.matched, default: 0]))
        result.append(contentsOf: Array(repeating: .uncertain, count: base[.uncertain, default: 0]))
        result.append(contentsOf: Array(repeating: .unmatched, count: base[.unmatched, default: 0]))

        if result.count > totalSegments {
            result = Array(result.prefix(totalSegments))
        } else if result.count < totalSegments {
            result.append(contentsOf: Array(repeating: .unmatched, count: totalSegments - result.count))
        }

        return result
    }

    private func fillColor(for kind: SegmentKind) -> Color {
        switch kind {
        case .matched:
            return matchedColor
        case .uncertain:
            return uncertainColor
        case .unmatched:
            return unmatchedColor
        }
    }

    private func tooltipText(kind: SegmentKind, matched: Int, uncertain: Int, unmatched: Int) -> String {
        switch kind {
        case .matched:
            return "\(matched) items matched"
        case .uncertain:
            return "\(uncertain) items uncertain"
        case .unmatched:
            return "\(unmatched) items unmatched"
        }
    }

    private func angleForSegment(index: Int) -> Double {
        Double(index) * Double.pi / Double(max(1, totalSegments - 1)) - Double.pi / 2
    }

    private func rotatedAngleForTooltip(index: Int) -> Double {
        angleForSegment(index: index) - Double.pi / 2
    }

    private func tooltipPoint(index: Int, in size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = outerRadius + 18
        let angle = rotatedAngleForTooltip(index: index)

        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )
    }

    private func segmentPoint(index: Int, in size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = outerRadius
        let angle = rotatedAngleForTooltip(index: index)

        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )
    }

    var body: some View {
        ZStack {
            ZStack {
                switch mode {
                case .single(let filledSegments):
                    ForEach(0..<totalSegments, id: \.self) { i in
                        let angle = Double(i) * Double.pi / Double(max(1, totalSegments - 1)) - Double.pi / 2
                        let fullWidth = (Double.pi / Double(max(1, totalSegments - 1))) * segmentWidthFactor
                        let isFilled = i < filledSegments

                        TaperedBar(
                            angle: angle,
                            width: fullWidth,
                            innerRadius: innerRadius,
                            outerRadius: outerRadius,
                            cornerRadius: 4
                        )
                        .fill(isFilled ? .orange : .grayScale30)
                    }
                case .breakdown(let matched, let uncertain, let unmatched):
                    let kinds = segmentsForBreakdown(
                        matched: matched,
                        uncertain: uncertain,
                        unmatched: unmatched
                    )

                    ForEach(0..<totalSegments, id: \.self) { i in
                        let angle = Double(i) * Double.pi / Double(max(1, totalSegments - 1)) - Double.pi / 2
                        let fullWidth = (Double.pi / Double(max(1, totalSegments - 1))) * segmentWidthFactor

                        let kind = kinds?[safe: i]
                        let hasData = kind != nil

                        let dimmed = selectedKind != nil && selectedKind != kind
                        let showShadow = selectedKind != nil && selectedKind == kind

                        TaperedBar(
                            angle: angle,
                            width: fullWidth,
                            innerRadius: innerRadius,
                            outerRadius: outerRadius,
                            cornerRadius: 4
                        )
                        .fill(hasData ? fillColor(for: kind!) : .grayScale30)
                        .opacity(dimmed ? 0.3 : 1)
                        .shadow(
                            color: showShadow ? Color.black.opacity(0.12) : .clear,
                            radius: showShadow ? 2 : 0,
                            x: 0,
                            y: 0
                        )
                        .animation(.easeInOut(duration: 0.25), value: selectedKind)
                        .contentShape(
                            TaperedBar(
                                angle: angle,
                                width: fullWidth,
                                innerRadius: innerRadius,
                                outerRadius: outerRadius,
                                cornerRadius: 4
                            )
                        )
                        .onTapGesture {
                            guard let kind else { return }
                            if selectedKind == kind {
                                selectedKind = nil
                            } else {
                                selectedKind = kind
                            }
                        }
                    }
                }
            }
            .frame(width: 460, height: 220)
            .rotationEffect(.degrees(-90))

            if case .breakdown(let matched, let uncertain, let unmatched) = mode,
               let selectedKind,
               let kinds = segmentsForBreakdown(matched: matched, uncertain: uncertain, unmatched: unmatched),
               let startIndex = kinds.firstIndex(where: { $0 == selectedKind }),
               let endIndex = kinds.lastIndex(where: { $0 == selectedKind }) {
                let selectedIndex = (startIndex + endIndex) / 2
                GeometryReader { proxy in
                    let tipPoint = tooltipPoint(index: selectedIndex, in: proxy.size)
                    let arcPoint = segmentPoint(index: selectedIndex, in: proxy.size)
                    let dx = arcPoint.x - tipPoint.x
                    let dy = arcPoint.y - tipPoint.y
                    let arrowAngle = atan2(dy, dx)

                    MatchingRateTooltipArrow()
                        .fill(.white)
                        .frame(width: 14, height: 8)
                        .rotationEffect(.radians(arrowAngle - .pi / 2))
                        .position(
                            x: tipPoint.x + dx * 0.22,
                            y: tipPoint.y + dy * 0.22
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                        .transaction { transaction in
                            transaction.animation = nil
                        }

                    HStack(spacing: 8) {
                        Circle()
                            .fill(fillColor(for: selectedKind))
                            .frame(width: 8, height: 8)

                        Text(tooltipText(kind: selectedKind, matched: matched, uncertain: uncertain, unmatched: unmatched))
                            .font(ManropeFont.medium.size(12))
                            .foregroundStyle(.grayScale150)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white)
                            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                    )
                    .position(tipPoint)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        if index < 0 || index >= count {
            return nil
        }
        return self[index]
    }
}

private struct MatchingRateTooltipArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct PreviewProvider_Previews: PreviewProvider {
    static var previews: some View {
        MatchingRateProgressBar()
    }
}




