import SwiftUI

struct AuthProviderCapsuleButton: View {
    enum Style {
        case outlined   // white background, gray border
        case filled     // black background, white text/icon
    }

    let title: String
    let iconAssetName: String?
    var systemIconName: String? = nil
    var isDisabled: Bool = false
    var action: () -> Void
    var titleColor: Color = .grayScale150
    var style: Style = .outlined

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemIconName {
                    Image(systemName: systemIconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(style == .filled ? .white : titleColor)
                } else if let iconAssetName {
                    Image(iconAssetName)
                        .resizable()
                        .frame(width: 24, height: 24)
                }

                Text(title)
                    .font(NunitoFont.semiBold.size(16))
                    .foregroundStyle(style == .filled ? .white : titleColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(style == .filled ? Color.black : Color.white, in: .capsule)
            .overlay(
                Capsule()
                    .stroke(style == .filled ? Color.clear : Color.grayScale40, lineWidth: 1)
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

