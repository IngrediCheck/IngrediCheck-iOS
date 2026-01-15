import SwiftUI

struct ScanningHelpCanvas: View {
    var body: some View {
        OnboardingPhoneCanvas(phoneImageName: "Iphone-image")
            .padding(.top ,20)
    }
}

#Preview {
    ScanningHelpCanvas()
}
