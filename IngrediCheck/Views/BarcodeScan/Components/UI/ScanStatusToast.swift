import SwiftUI

/// Toast message view displaying scan status with animated shimmer effect
struct ScanStatusToast: View {
    let state: ToastScanState
    
    @State private var shimmerPhase: CGFloat = -1
    // Wider and slower shimmer so it's very visible to the eye.
    private let shimmerGradientWidth: CGFloat = 110
    private let animationDuration: Double = 1.8
    
    private var iconName: String {
        switch state {
        case .scanning:
            return "ic_round-tips-and-updates"
        default:
            // For all non-scanning states we use the analysis icon
            return "analysisicon"
        }
    }
    
    private var message: String {
        switch state {
        case .scanning:
            return "Ensure good lighting and steady hands"
        case .extractionSuccess:
            return "Scanning successful. Fetching data…"
        case .notIdentified:
            return "Scan again or add photos for better results."
        case .analyzing:
            return "Product detected, reading ingredients."
        case .match:
            return "Good news! This product matches your preferences."
        case .notMatch:
            return "This product might not align with your choices."
        case .uncertain:
            return "Some ingredients need verification."
        case .retry:
            return "Let's try again for a clearer scan."
        case .photoGuide:
            return "Capture clear photos of the product label"
        case .dynamicGuidance(let guidance):
            return guidance  // Use dynamic message from API
        }
    }
    
    var body: some View {
        labelContent
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.bar)
                    .opacity(0.4)
            )
            .overlay(
                // Shimmer effect - moves left to right across the dynamic content width
                GeometryReader { geo in
                    let width = geo.size.width
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.9),
                            Color.white.opacity(1.0),
                            Color.white.opacity(0.9),
                            Color.white.opacity(0.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: shimmerGradientWidth)
                    // Move the shimmer a bit farther so it fully covers
                    // the last characters instead of stopping short.
                    .offset(x: shimmerPhase * (width + shimmerGradientWidth))
                    // Screen blend mode makes the highlight much more visible
                    // over the dimmed base text/icon.
                    .blendMode(.screen)
                }
                .mask(
                    labelContent
                        .frame(height: 36)
                )
            )
            .onAppear {
                startShimmer()
            }
            .onChange(of: state) { _ in
                startShimmer()
            }
            .animation(.easeInOut(duration: 0.2), value: state)
    }
    
    @ViewBuilder
    private var labelContent: some View {
        HStack(spacing: 8) {
            Image(iconName)
                .resizable()
                .renderingMode(.template)
                .frame(width: 19, height: 19)
                .foregroundColor(.white.opacity(0.6))
            
            Text(message)
                .font(ManropeFont.medium.size(12))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)  // Max 16px horizontal padding
    }
    
    private func startShimmer() {
        shimmerPhase = -1
        withAnimation(
            Animation
                .linear(duration: animationDuration)
                .delay(0.1)
                .repeatForever(autoreverses: false)
        ) {
            shimmerPhase = 1
        }
    }
}
