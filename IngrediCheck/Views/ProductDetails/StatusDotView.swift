
import SwiftUI

struct StatusDotView: View {
    let status: ProductMatchStatus
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Pulse Ring (Only for analyzing state)
            if status == .analyzing {
                Circle()
                    .fill(status.color)
                    .frame(width: 10, height: 10)
                    .scaleEffect(isPulsing ? 2.5 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.3) // Starts with mild opacity and fades out
                    .onAppear {
                        // Reset state first to ensure animation restarts if view recycles
                        isPulsing = false
                        // Use a slight delay to ensure the view is ready, then animate
                        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                            isPulsing = true
                        }
                    }
            }
            
            // Core Dot
            Circle()
                .fill(status.color)
                .frame(width: 10, height: 10)
        }
    }
}

#Preview {
    StatusDotView(status: .analyzing)
}
