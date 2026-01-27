import SwiftUI

struct QuickAccessSheet: View {
    let onBack: () -> Void
    let onGoToHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
//            HStack {
//                Spacer()
//                Button(action: onBack) {
//                    Image(systemName: "chevron.right")
//                        .font(.system(size: 18, weight: .semibold))
//                        .foregroundStyle(.grayScale150)
//                        .frame(width: 44, height: 44)
//                        .contentShape(Rectangle())
//                }
//                .buttonStyle(.plain)
//            }
//            .padding(.top, 8)

            Text("Quick access needed")
                .font(NunitoFont.bold.size(22))
                .foregroundStyle(.grayScale150)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            Text("So we can scan products and personalize results for you.")
                .font(ManropeFont.regular.size(13))
                .foregroundStyle(Color(hex: "#BDBDBD"))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 24)

            Button(action: onGoToHome) {
                GreenCapsule(title: "Go to Home", width: 159, takeFullWidth: false)
                    .frame(width: 159, height: 52)
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
}

#Preview {
    QuickAccessSheet(onBack: {}, onGoToHome: {})
}
