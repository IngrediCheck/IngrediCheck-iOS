import SwiftUI

struct LoginToContinueSheet: View {
    @Environment(AuthController.self) private var authController

    let onBack: () -> Void
    let onSignedIn: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.grayScale150)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.top, 8)

            Text("Log in to continue")
                .font(NunitoFont.bold.size(22))
                .foregroundStyle(.grayScale150)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            Text("Sign in to save your preferences and scans, and keep\n them in sync across devices.")
                .font(ManropeFont.medium.size(12))
                .foregroundStyle(.grayScale120)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
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
                            .frame(width: 18, height: 18)
                        Text("Google")
                            .font(NunitoFont.semiBold.size(14))
                            .foregroundStyle(.grayScale150)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#F7F7F7"), in: .capsule)
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
                            .frame(width: 18, height: 18)
                        Text("Apple")
                            .font(NunitoFont.semiBold.size(14))
                            .foregroundStyle(.grayScale150)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#F7F7F7"), in: .capsule)
                }
                .buttonStyle(.plain)
                .disabled(authController.isUpgradingAccount)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 21)
        .padding(.bottom, 24)
    }
}

#Preview {
    LoginToContinueSheet(onBack: {}, onSignedIn: {})
}
