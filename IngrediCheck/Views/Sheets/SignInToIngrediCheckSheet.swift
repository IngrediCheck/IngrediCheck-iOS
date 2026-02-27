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
                signInButton(
                    title: "Google",
                    icon: Image("google_logo"),
                    iconSize: 24,
                    action: onGoogle
                )

                signInButton(
                    title: "Apple",
                    icon: Image("apple_logo"),
                    iconSize: 24,
                    action: onApple
                )
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)

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

            Button {
                onContinueAsGuest?()
            } label: {
                Text("Continue as Guest")
                    .font(NunitoFont.semiBold.size(16))
                    .foregroundStyle(Color(hex: "6B8E06"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.grayScale30, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .padding(.horizontal, 24)

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
            .padding(.top, 18)
            .padding(.bottom, 28)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: 375)
        .background(Color.white)
    }

    private func signInButton(
        title: String,
        icon: Image,
        iconSize: CGFloat,
        action: (() -> Void)?
    ) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 8) {
                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                Text(title)
                    .font(NunitoFont.semiBold.size(16))
                    .foregroundStyle(.grayScale150)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.grayScale30, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

