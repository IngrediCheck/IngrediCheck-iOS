import SwiftUI
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift
import os

struct SignInView: View {

    @Environment(AuthController.self) var authController
    @Environment(OnboardingState.self) var onboardingState

    var body: some View {
        ZStack {
            Image("SplashScreen")
                .resizable()
                .scaledToFill()

            VStack(spacing: 40) {

                Spacer()

                VStack(spacing: 20) {
                    SignInWithAppleButton(
                        .continue,
                        onRequest: { (request) in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            onboardingState.useCasesShown = true
                            authController.handleSignInWithAppleCompletion(result: result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 45)

                    // Custom Google Sign-In Button
                    Button(action: {
                        authController.signInWithGoogle { result in
                            switch result {
                            case .success:
                                onboardingState.useCasesShown = true
                            case .failure(let error):
                                // TODO: Show an alert to the user
                                Log.error("SignInView", "Google Sign-In failed: \(error.localizedDescription)")
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            // For brand compliance, you should download the official "G" logo
                            // from Google's branding guidelines and add it to your assets.
                            // Then uncomment the following lines:
                             Image("google_logo")
                                 .resizable()
                                 .aspectRatio(contentMode: .fit)
                                 .frame(width: 16, height: 16)

                            Text("Continue with Google")
                                .font(.system(size: 16))
                                .fontWeight(.medium)
                                .foregroundColor(.black.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 45)
                        .background(Color.white)
                        .cornerRadius(8) // You can adjust this value
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                    }
                    
                    Button {
                        onboardingState.useCasesShown = true
                        Task {
                            await authController.signIn()
                        }
                    } label: {
                        Text("Sign in later")
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.paletteAccent)
                }
                .padding(.horizontal)

                LegalDisclaimerView(showShieldIcon: false)
                    .padding(.horizontal)
                    .padding(.horizontal)
                    .padding(.horizontal)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .padding(.bottom)
                    .padding(.bottom)
            }
        }
    }
}

#Preview {
    SignInView()
}
