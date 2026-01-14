import SwiftUI

struct ScanningHelpSheet: View {
    let onBack: () -> Void
    let onGotIt: () -> Void

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

            Text("See how scanning works")
                .font(NunitoFont.bold.size(22))
                .foregroundStyle(.grayScale150)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            Text("Here’s a quick look at how you can scan products\nwhen you’re ready.")
                .font(ManropeFont.regular.size(13))
                .foregroundStyle(Color(hex: "#BDBDBD"))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 24)

            Button(action: onGotIt) {
                GreenCapsule(title: "Got it", width: 159, takeFullWidth: false)
                    .frame(width: 159, height: 52)
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 21)
        .padding(.bottom, 24)
    }
}

#Preview {
    ScanningHelpSheet(onBack: {}, onGotIt: {})
}
