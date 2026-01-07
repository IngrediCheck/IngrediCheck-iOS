import SwiftUI
import UIKit

/// Overlay view that creates a dark semi-transparent mask with a rounded cutout
struct CutoutOverlay: View {
    var rect: CGRect

    var body: some View {
        Color.black.opacity(0.5)
            .mask(
                CutoutShape(rect: rect)
                    .fill(style: FillStyle(eoFill: true))
            )
            .ignoresSafeArea()
    }
}

/// Shape that creates a full-screen rectangle with a rounded cutout hole
struct CutoutShape: Shape {
    let rect: CGRect
    let cornerRadius: CGFloat = 12

    func path(in bounds: CGRect) -> Path {
        var path = Path()

        // Full dark overlay
        path.addRect(bounds)

        // Rounded transparent hole
        let rounded = UIBezierPath(
            roundedRect: rect,
            cornerRadius: cornerRadius
        )
        path.addPath(Path(rounded.cgPath))

        return path
    }
}
