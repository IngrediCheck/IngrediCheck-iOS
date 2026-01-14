import SwiftUI

struct OnboardingPhoneCanvas: View {
    let phoneImageName: String

    init(phoneImageName: String = "Iphone-image") {
        self.phoneImageName = phoneImageName
    }

    var body: some View {
        VStack {
            Image("Ingredicheck-logo")
                .frame(width: 107.3, height: 36)
                .padding(.top, 44)
                .padding(.bottom, 33)

            ZStack {
                Image(phoneImageName)
                    .resizable()
                    .frame(width: 238, height: 460)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#FFFFFF"),
                    Color(hex: "#F7F7F7"),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.white,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .offset(y: 75)
        )
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    OnboardingPhoneCanvas()
}
