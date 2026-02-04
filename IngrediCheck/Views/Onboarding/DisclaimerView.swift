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
                    
                    Microcopy.text(Microcopy.Key.Disclaimer.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Microcopy.text(Microcopy.Key.Disclaimer.body)
                }

                Spacer()

                Button {
                    onboardingState.disclaimerShown = true
                } label: {
                    Microcopy.text(Microcopy.Key.Disclaimer.ctaUnderstand)
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
