import SwiftUI

struct LoginToContinueSheet: View {
    @Environment(AuthController.self) private var authController

    let onBack: () -> Void
    let onSignedIn: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // CENTER TEXT
                Text("Log in to continue")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                // LEFT ICON
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.grayScale150)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                        Spacer()
                    }
                    .buttonStyle(.plain)

                    
                }
            }
            .padding(.top, 8)

            Text("Sign in to save your preferences and scans, and keep\n them in sync across devices.")
                .font(ManropeFont.medium.size(12))
                .foregroundStyle(.grayScale120)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 24)

            HStack(spacing: 16) {
                Button {
                    Task {
                        await authController.upgradeCurrentAccount(to: .google)
                        await MainActor.run {
                            if authController.session != nil && !authController.signedInAsGuest {
                                onSignedIn()
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image("google_logo")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text("Google")
                            .font(NunitoFont.semiBold.size(16))
                            .foregroundStyle(.grayScale150)
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
                .disabled(authController.isUpgradingAccount)

                Button {
                    Task {
                        await authController.upgradeCurrentAccount(to: .apple)
                        await MainActor.run {
                            if authController.session != nil && !authController.signedInAsGuest {
                                onSignedIn()
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image("apple_logo")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text("Apple")
                            .font(NunitoFont.semiBold.size(16))
                            .foregroundStyle(.grayScale150)
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
                .disabled(authController.isUpgradingAccount)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 21)
        .padding(.bottom, 24)
    }
}

#Preview {
    LoginToContinueSheet(onBack: {}, onSignedIn: {})
}
