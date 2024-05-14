import SwiftUI
import AuthenticationServices

struct UseCasesView: View {

    @Environment(OnboardingState.self) var onboardingState
    @Environment(AuthController.self) var authController
    
    private static let useCaseImages = [
        "Onboarding1",
        "Onboarding2",
        "Onboarding3"
    ]

    @State private var currentTabViewIndex = 0

    var body: some View {
        
        VStack(spacing: 40) {
            
            VStack(spacing: 0) {
                TabView(selection: $currentTabViewIndex.animation()) {
                    ForEach(0 ..< UseCasesView.useCaseImages.count, id:\.self) { index in
                        Image(UseCasesView.useCaseImages[index])
                            .resizable()
                            .scaledToFit()
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    ThreeDotsIndexView(
                        numberOfPages: UseCasesView.useCaseImages.count,
                        currentIndex: currentTabViewIndex
                    )
            }
            
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
        }
    }
}

#Preview {
    UseCasesView()
}
