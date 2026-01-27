import SwiftUI

struct ScanningHelpCanvas: View {
    var body: some View {
        VStack {
            // Video placeholder - will be replaced with actual video player
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 300)
                .overlay(
                    VStack {
                        Image(systemName: "play.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Video coming soon")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                )
                .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 40)
    }
}

#Preview {
    ScanningHelpCanvas()
}
