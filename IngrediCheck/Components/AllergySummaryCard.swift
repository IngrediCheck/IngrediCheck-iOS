//
//  AllergySummaryCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

struct MyIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.13143*width, y: height))
        path.addCurve(to: CGPoint(x: 0, y: 0.88265*height), control1: CGPoint(x: 0.05884*width, y: height), control2: CGPoint(x: 0, y: 0.94746*height))
        path.addLine(to: CGPoint(x: 0, y: 0.11735*height))
        path.addCurve(to: CGPoint(x: 0.13143*width, y: 0), control1: CGPoint(x: 0, y: 0.05254*height), control2: CGPoint(x: 0.05884*width, y: 0))
        path.addLine(to: CGPoint(x: 0.86857*width, y: 0))
        path.addCurve(to: CGPoint(x: width, y: 0.11735*height), control1: CGPoint(x: 0.94115*width, y: 0), control2: CGPoint(x: width, y: 0.05254*height))
        path.addLine(to: CGPoint(x: width, y: 0.59843*height))
        path.addCurve(to: CGPoint(x: 0.8531*width, y: 0.72959*height), control1: CGPoint(x: width, y: 0.67087*height), control2: CGPoint(x: 0.93423*width, y: 0.72959*height))
        path.addCurve(to: CGPoint(x: 0.70621*width, y: 0.86075*height), control1: CGPoint(x: 0.77198*width, y: 0.72959*height), control2: CGPoint(x: 0.70621*width, y: 0.78831*height))
        path.addLine(to: CGPoint(x: 0.70621*width, y: 0.8648*height))
        path.addCurve(to: CGPoint(x: 0.55478*width, y: height), control1: CGPoint(x: 0.70621*width, y: 0.93947*height), control2: CGPoint(x: 0.63841*width, y: height))
        path.addLine(to: CGPoint(x: 0.13143*width, y: height))
        path.closeSubpath()
        return path
    }
}

struct AllergySummaryCard: View {
    var summary: String? = nil
    var onTap: (() -> Void)? = nil

    private var emptyStateFormattedText: String {
        formatCardText("\"Add *allergies* or *dietary* needs for your *family* members to make meal *choices* easier for everyone.\"")
    }

    /// Returns true if we should show the empty state (no data yet)
    private var isEmptyState: Bool {
        guard let summary = summary else { return true }
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "No Food Notes yet."
    }

    var body: some View {
        ZStack {
            // Tappable background
            MyIcon()
                .fill(.grayScale10)
                .overlay(
                    MyIcon()
                        .stroke(lineWidth: 0.25)
                        .foregroundStyle(.grayScale60)
                )
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
                .contentShape(MyIcon())
                .onTapGesture {
                    onTap?()
                }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                if isEmptyState {
                    // Empty state: "No Data Yet" badge + placeholder text
                    Text("No Data Yet")
                        .font(ManropeFont.regular.size(8))
                        .foregroundStyle(.grayScale130)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(.grayScale30, in: .capsule)
                        .overlay(
                            Capsule()
                                .stroke(lineWidth: 0.5)
                                .foregroundStyle(.grayScale70)
                        )

                    MultiColorText(text: emptyStateFormattedText)
                        .padding(.trailing, 10)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(6)
                } else {
                    // Has summary: show the AI-generated summary text
                    Text("\"\(summary!)\"")
                        .font(ManropeFont.bold.size(14))
                        .foregroundStyle(.grayScale140)
                        .padding(.trailing, 10)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 17)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
            
            // Button overlay - takes priority
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        onTap?()
                    }) {
                        GreenCircle(iconName: "arrow-up-right", iconSize: 20, circleSize: 37)
                            .padding(3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 3)
            .padding(.trailing, 3)
        }
    }
}

#Preview {
    AllergySummaryCard()
}
