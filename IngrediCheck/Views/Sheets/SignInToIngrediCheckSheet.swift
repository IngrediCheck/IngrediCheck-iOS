import SwiftUI

struct SignInToIngrediCheckSheet: View {
    var onGoogle: (() -> Void)?
    var onApple: (() -> Void)?
    var onContinueAsGuest: (() -> Void)?
    var onTermsAndPrivacy: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Text("Sign in to IngrediCheck")
                .font(NunitoFont.bold.size(22))
                .foregroundStyle(.grayScale150)
                .multilineTextAlignment(.center)
                .padding(.top, 26)

            Text("Continue to personalized ingredient insights\nfor you and your family.")
                .font(ManropeFont.medium.size(12))
                .foregroundStyle(.grayScale120)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            HStack(spacing: 16) {
                AuthProviderCapsuleButton(
                    title: "Google",
                    iconAssetName: "google_logo",
                    action: { onGoogle?() }
                )

                AuthProviderCapsuleButton(
                    title: "Apple",
                    iconAssetName: "apple_logo",
                    action: { onApple?() }
                )
            }
            .padding(.top, 28)
            .padding(.horizontal, 20)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(colors: [Color(hex: "#D6D4D4"), .white], startPoint: .trailing, endPoint: .leading)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
                
                Text("Or")
                    .font(ManropeFont.medium.size(10))
                    .foregroundStyle(.grayScale120)
                    .padding(.horizontal, 7)
                
                Rectangle()
                    .fill(
                        LinearGradient(colors: [Color(hex: "#D6D4D4"), .white], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
            }
            .padding(.top, 18)
            .padding(.horizontal, 24)

            AuthProviderCapsuleButton(title: "Continue as Guest", iconAssetName: nil,action: {}, titleColor: .primary800)
                .padding(.horizontal, 20)
                .padding(.top, 14)

            Button {
                onTermsAndPrivacy?()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "shield")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.grayScale70)

                    Text("By continuing, you agree to our ")
                        .foregroundStyle(.grayScale70)
                    + Text("Terms & Privacy Policy.")
                        .foregroundStyle(.grayScale70)
                        .font(ManropeFont.semiBold.size(12))
                }
                .font(ManropeFont.medium.size(12))
                .multilineTextAlignment(.center)
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
            .padding(.bottom, 28)
            .padding(.horizontal, 24)
        }
        .background(Color.white)
    }
}

#Preview {
    SignInToIngrediCheckSheet(
        onGoogle: {},
        onApple: {},
        onContinueAsGuest: {},
        onTermsAndPrivacy: {}
    )
}
