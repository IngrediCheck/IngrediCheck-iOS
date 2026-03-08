import SwiftUI

struct SignInToIngrediCheckSheet: View {
    @Environment(AuthController.self) private var authController
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @State private var isSigningIn = false
    @State private var authErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Text("Sign in to IngrediCheck")
                .font(NunitoFont.bold.size(22))
                .foregroundStyle(.grayScale150)
                .multilineTextAlignment(.center)
                .padding(.top, 26)

            Text("Sign in to sync your preferences\nand pick up where you left off.")
                .font(ManropeFont.medium.size(12))
                .foregroundStyle(.grayScale120)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            HStack(spacing: 16) {
                AuthProviderCapsuleButton(
                    title: "Google",
                    iconAssetName: "google_logo",
                    isDisabled: isSigningIn,
                    action: handleGoogleSignIn
                )
                .accessibilityIdentifier("auth_google_button")

                AuthProviderCapsuleButton(
                    title: "Apple",
                    iconAssetName: "apple_logo",
                    isDisabled: isSigningIn,
                    action: handleAppleSignIn
                )
                .accessibilityIdentifier("auth_apple_button")
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)

            if let authErrorMessage {
                Text(authErrorMessage)
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                    .accessibilityIdentifier("auth_error_message")
            }

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
                Task {
                    authErrorMessage = nil
                    isSigningIn = true
                    await authController.signIn()
                    coordinator.navigateInBottomSheet(.whosThisFor)
                    isSigningIn = false
                }
            } label: {
                GreenCapsule(title: "Sign in later", takeFullWidth: true)
            }
            .buttonStyle(.plain)
            .disabled(isSigningIn)
            .padding(.top, 18)
            .padding(.horizontal, 24)
            .accessibilityIdentifier("auth_guest_button")

            LegalDisclaimerView()
            .padding(.top, 24)
            .padding(.bottom, 24)
            .padding(.horizontal, 24)
        }
        .background(Color.white)
        .accessibilityIdentifier("sign_in_sheet")
        .overlay {
            if isSigningIn {
                ZStack {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .scaleEffect(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func handleGoogleSignIn() {
        authErrorMessage = nil
        isSigningIn = true
        authController.signInWithGoogle { result in
            switch result {
            case .success:
                Task {
                    if UITestHarness.isEnabled {
                        await MainActor.run {
                            if UITestHarness.fixture?.marksOnboardingCompleted == true {
                                coordinator.showCanvas(.home)
                                coordinator.navigateInBottomSheet(.homeDefault)
                            } else {
                                coordinator.showCanvas(.letsGetStarted)
                                coordinator.navigateInBottomSheet(.whosThisFor)
                            }
                            isSigningIn = false
                        }
                        return
                    }
                    let metadata = await OnboardingPersistence.shared.fetchRemoteMetadata()
                    Log.debug("SignInToIngrediCheckSheet", "Google sign-in metadata: stage=\(metadata?.stage?.rawValue ?? "nil"), flowType=\(metadata?.flowType?.rawValue ?? "nil"), stepId=\(metadata?.currentStepId ?? "nil"), bottomSheet=\(metadata?.bottomSheetRoute?.rawValue ?? "nil")")
                    await MainActor.run {
                        if let stage = metadata?.stage, stage == .completed {
                            AnalyticsService.shared.trackOnboarding("Onboarding Existing User Completed", properties: ["sign_in_method": "google"])
                            OnboardingPersistence.shared.markCompleted()
                            coordinator.showCanvas(.home)
                        } else if let metadata = metadata, let stage = metadata.stage, stage != .none, stage != .preOnboarding {
                            let (canvas, sheet) = AppNavigationCoordinator.restoreState(from: metadata)
                            Log.debug("SignInToIngrediCheckSheet", "Restoring to canvas=\(canvas), sheet=\(sheet)")
                            coordinator.showCanvas(canvas)
                            coordinator.navigateInBottomSheet(sheet)
                        } else {
                            Log.debug("SignInToIngrediCheckSheet", "No metadata or no progress — navigating to whosThisFor")
                            coordinator.showCanvas(.letsGetStarted)
                            coordinator.navigateInBottomSheet(.whosThisFor)
                        }
                        isSigningIn = false
                    }
                }
            case .failure(let error):
                Log.error("SignInToIngrediCheckSheet", "Google Sign-In failed: \(error.localizedDescription)")
                Task { @MainActor in
                    authErrorMessage = error.localizedDescription
                    isSigningIn = false
                }
            }
        }
    }

    private func handleAppleSignIn() {
        authErrorMessage = nil
        isSigningIn = true
        authController.signInWithApple { result in
            switch result {
            case .success:
                Task {
                    if UITestHarness.isEnabled {
                        await MainActor.run {
                            if UITestHarness.fixture?.marksOnboardingCompleted == true {
                                coordinator.showCanvas(.home)
                                coordinator.navigateInBottomSheet(.homeDefault)
                            } else {
                                coordinator.showCanvas(.letsGetStarted)
                                coordinator.navigateInBottomSheet(.whosThisFor)
                            }
                            isSigningIn = false
                        }
                        return
                    }
                    let metadata = await OnboardingPersistence.shared.fetchRemoteMetadata()
                    Log.debug("SignInToIngrediCheckSheet", "Apple sign-in metadata: stage=\(metadata?.stage?.rawValue ?? "nil"), flowType=\(metadata?.flowType?.rawValue ?? "nil"), stepId=\(metadata?.currentStepId ?? "nil"), bottomSheet=\(metadata?.bottomSheetRoute?.rawValue ?? "nil")")
                    await MainActor.run {
                        if let stage = metadata?.stage, stage == .completed {
                            AnalyticsService.shared.trackOnboarding("Onboarding Existing User Completed", properties: ["sign_in_method": "apple"])
                            OnboardingPersistence.shared.markCompleted()
                            coordinator.showCanvas(.home)
                        } else if let metadata = metadata, let stage = metadata.stage, stage != .none, stage != .preOnboarding {
                            let (canvas, sheet) = AppNavigationCoordinator.restoreState(from: metadata)
                            Log.debug("SignInToIngrediCheckSheet", "Restoring to canvas=\(canvas), sheet=\(sheet)")
                            coordinator.showCanvas(canvas)
                            coordinator.navigateInBottomSheet(sheet)
                        } else {
                            Log.debug("SignInToIngrediCheckSheet", "No metadata or no progress — navigating to whosThisFor")
                            coordinator.showCanvas(.letsGetStarted)
                            coordinator.navigateInBottomSheet(.whosThisFor)
                        }
                        isSigningIn = false
                    }
                }
            case .failure(let error):
                Log.error("SignInToIngrediCheckSheet", "Apple Sign-In failed: \(error.localizedDescription)")
                Task { @MainActor in
                    authErrorMessage = error.localizedDescription
                    isSigningIn = false
                }
            }
        }
    }
}

#Preview {
    SignInToIngrediCheckSheet()
        .environment(AuthController())
        .environment(AppNavigationCoordinator(initialRoute: .heyThere))
}
