import SwiftUI

struct LoginToContinueSheet: View {
    @Environment(AuthController.self) private var authController

    let onBack: () -> Void
    let onSignedIn: () -> Void
    let showAsAlert: Bool

    @State private var showUpgradeError = false
    @State private var upgradeErrorMessage = ""

    init(onBack: @escaping () -> Void, onSignedIn: @escaping () -> Void, showAsAlert: Bool = false) {
        self.onBack = onBack
        self.onSignedIn = onSignedIn
        self.showAsAlert = showAsAlert
    }

    var body: some View {
        Group {
            if showAsAlert {
                alertStyleView
            } else {
                sheetStyleView
            }
        }
        .overlay(alignment: .center) {
            if authController.isUpgradingAccount {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(2)
                }
            }
        }
        .onChange(of: authController.accountUpgradeError?.localizedDescription ?? "", initial: false) { _, message in
            guard !message.isEmpty else { return }
            upgradeErrorMessage = message
            showUpgradeError = true
        }
        .alert("Sign-in Failed", isPresented: $showUpgradeError) {
            Button("OK", role: .cancel) {
                Task { @MainActor in
                    authController.accountUpgradeError = nil
                }
            }
        } message: {
            Text(upgradeErrorMessage)
        }
    }
    
    private var alertStyleView: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onBack()
                }
            
            // Alert card
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Spacer()
                    Button(action: onBack) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.grayScale130)
                            .frame(width: 32, height: 32)
                            .background(Color.grayScale20)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
                
                // Title
                Text("Log in to continue")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                
                // Subtitle
                Text("Sign in to save your preferences and scans, and keep\n them in sync across devices.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                
                // Sign in buttons
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
                .padding(.bottom, 32)
                .padding(.horizontal, 24)
            }
            .frame(width: 327)
            .background(Color.white)
            .cornerRadius(40)
            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        }
    }
    
    private var sheetStyleView: some View {
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
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
}

#Preview("Alert Style") {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        LoginToContinueSheet(
            onBack: {},
            onSignedIn: {},
            showAsAlert: true
        )
        .environment(AuthController())
    }
}

#Preview("Sheet Style") {
    LoginToContinueSheet(
        onBack: {},
        onSignedIn: {},
        showAsAlert: false
    )
    .environment(AuthController())
}
