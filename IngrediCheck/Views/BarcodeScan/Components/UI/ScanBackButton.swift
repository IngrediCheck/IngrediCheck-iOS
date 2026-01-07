import SwiftUI

/// Back button for dismissing the camera screen
struct ScanBackButton: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Button {
            dismiss()
        } label: {
            ZStack {
                Image("angle-left-arrow")
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
            }
            .frame(width: 33, height: 33)
            .background(
                .bar.opacity(0.4), in: .capsule
            )
        }
        .buttonStyle(.plain)
    }
}
