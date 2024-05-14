import SwiftUI
import AuthenticationServices

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
                    
                    Button {
                        onboardingState.useCasesShown = true
                        Task {
                            await authController.signIn()
                        }
                    } label: {
                        Text("Continue as Guest")
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.paletteAccent)
                }
                .padding(.horizontal)

                Text("By continuing, you are agreeing to my **[Terms of Use](https://www.ingredicheck.app/terms-conditions)** and **[Privacy Policy](https://www.ingredicheck.app/privacy-policy)**.")
                    .multilineTextAlignment(.center)
                    .font(.footnote)
                    .tint(.paletteAccent)
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
