import SwiftUI

struct AuthProviderCapsuleButton: View {
    let title: String
    let iconAssetName: String?
    var isDisabled: Bool = false
    var action: () -> Void
    var titleColor: Color = .grayScale150

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let iconAssetName {
                    Image(iconAssetName)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                

                Text(title)
                    .font(NunitoFont.semiBold.size(16))
                    .foregroundStyle(titleColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white, in: .capsule)
            .overlay(
                Capsule()
                    .stroke(Color.grayScale40, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

#Preview {
    VStack(spacing: 12) {
        AuthProviderCapsuleButton(title: "Google", iconAssetName: "google_logo", action: {})
        AuthProviderCapsuleButton(title: "Apple", iconAssetName: "apple_logo", action: {})
        AuthProviderCapsuleButton(title: "Continue as Guest", iconAssetName: nil,action: {}, titleColor: .primary800)
    }
    .padding()
}

