//
//  FlowLayout.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import SwiftUI

// Custom flow layout with separate horizontal and vertical spacing
struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 4
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.init(width: maxWidth, height: nil))

            if x + size.width > maxWidth { // move to next line
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            rowHeight = max(rowHeight, size.height)
            x += size.width + horizontalSpacing
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.init(width: bounds.width, height: nil))

            if x + size.width > bounds.width { // new line
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(size)
            )

            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}



//#Preview {
//    FlowLayout()
//}
