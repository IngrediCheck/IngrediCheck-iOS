import SwiftUI

struct ReadyToScanSheet: View {
    let onBack: () -> Void
    let onNotRightNow: () -> Void
    let onHaveAProduct: () -> Void

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

            Text("Ready to scan your\nfirst product?")
                .font(NunitoFont.bold.size(22))
                .foregroundStyle(.grayScale150)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            Text("Do you have any food product around you right now?")
                .font(ManropeFont.regular.size(13))
                .foregroundStyle(Color(hex: "#BDBDBD"))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Button(action: onNotRightNow) {
                    Text("Not right now")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(Color(hex: "#BDBDBD"))
                        .frame(height: 52)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(Color(hex: "#EBEBEB"))
                        )
                }
                .buttonStyle(.plain)

                Button(action: onHaveAProduct) {
                    GreenCapsule(title: "Have a product")
                        .frame(height: 52)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 21)
        .padding(.bottom, 24)
    }
}

#Preview {
    ReadyToScanSheet(
        onBack: {},
        onNotRightNow: {},
        onHaveAProduct: {}
    )
}
