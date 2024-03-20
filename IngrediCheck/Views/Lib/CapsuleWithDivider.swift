import SwiftUI

struct CapsuleWithDivider<Content: View>: View {

    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            content()
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .padding(.vertical, 15)
            Spacer()
        }
        .background(
            color.opacity(0.05)
        )
    }
}

#Preview {
    VStack {
        CapsuleWithDivider(color: .blue) {
            HStack(spacing: 25) {
                ProgressView()
                Text("Analyzing")
            }
        }
        CapsuleWithDivider(color: .green) {
            HStack(spacing: 15) {
                Image(systemName: "checkmark.circle.fill")
                Text("Matched")
            }
        }
        CapsuleWithDivider(color: .yellow) {
            HStack(spacing: 15) {
                Image(systemName: "questionmark.circle.fill")
                Text("Uncertain")
            }
        }
        CapsuleWithDivider(color: .red) {
            HStack(spacing: 15) {
                Image(systemName: "x.circle.fill")
                Text("Unmatched")
            }
        }
    }
}
