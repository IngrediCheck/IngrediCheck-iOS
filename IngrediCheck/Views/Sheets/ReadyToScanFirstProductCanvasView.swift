
import SwiftUI

struct ReadyToScanCanvas: View {
    var body: some View {
        VStack {
            Spacer()

            Image("Iphone-image")
                .resizable()
                .scaledToFit()
                .frame(width: 238, height: 460)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#FFFFFF"),
                    Color(hex: "#F7F7F7"),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.white,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .offset(y: 75)
        )
    }
}

#Preview {
    ReadyToScanCanvas()
}

