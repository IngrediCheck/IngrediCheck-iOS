import SwiftUI

struct DisclaimerView: View {

    @Environment(OnboardingState.self) var onboardingState

    var body: some View {
        ZStack {
            Image("Background")
                .resizable()
                .scaledToFill()

            VStack(spacing: 0) {

                Spacer()

                VStack(spacing: 20) {
                    Image("LogoGreen")
                    
                    Text("Welcome to IngrediCheck!")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("IngrediCheck is powered by some cool AI to help you check if your food matches your dietary needs. Remember, the AI isn’t always spot-on, so trust your own judgment. AI does improve with feedback, so please use the feedback button to share your thoughts and contribute product images. It will help make the AI even better for everyone!")
                }

                Spacer()

                Button {
                    onboardingState.disclaimerShown = true
                } label: {
                    Text("I Understand")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .background(.paletteAccent)
                        .clipShape(.capsule)
                }

                Spacer()
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal)
        }
    }
}

#Preview {
    DisclaimerView()
}
