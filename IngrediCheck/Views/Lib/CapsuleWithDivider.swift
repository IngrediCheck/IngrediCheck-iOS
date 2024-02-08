
import SwiftUI

struct CapsuleWithDivider<Content: View>: View {

    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                line
                content()
                    .frame(width: geometry.size.width *  0.4)
                    .lineLimit(1)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .layoutPriority(1)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.3))
                    )
                    .overlay(
                        Capsule().stroke(color, lineWidth: 1)
                    )
                line
            }
        }
    }
    
    var line: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}


#Preview {
    CapsuleWithDivider(color: .blue) {
        HStack(spacing: 25) {
            Text("Analyzing")
            ProgressView()
        }
    }
}
