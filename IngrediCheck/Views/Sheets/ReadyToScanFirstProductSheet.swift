import SwiftUI

struct ReadyToScanSheet: View {
    let onBack: () -> Void
    let onNotRightNow: () -> Void
    let onHaveAProduct: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // CENTER TEXT
                Microcopy.text(Microcopy.Key.Onboarding.ReadyToScan.title)
                    .font(NunitoFont.bold.size(22))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.grayScale150)
                    .padding(.top, 4)

                // LEFT ICON
//                HStack {
//                    Button(action: onBack) {
//                        Image(systemName: "chevron.left")
//                            .font(.system(size: 18, weight: .semibold))
//                            .foregroundStyle(.grayScale150)
//                            .frame(width: 24, height: 24)
//                            .contentShape(Rectangle())
//                        Spacer()
//                    }
//                    .buttonStyle(.plain)
//
//                    
//                }
            }
            .padding(.top, 8)

            Microcopy.text(Microcopy.Key.Onboarding.ReadyToScan.subtitle)
                .font(ManropeFont.medium.size(12))
                .foregroundStyle(.grayScale120)
                .padding(.top, 12)
                .padding(.bottom, 24)

            HStack(spacing: 16) {
//                Button(action: onNotRightNow) {
//                    Text("Not right now")
//                        .font(NunitoFont.semiBold.size(16))
//                        .foregroundStyle(.grayScale110)
//                        .frame( width : 159 ,height: 52 )
//                        .background(
//                            Capsule().fill(.grayScale40)
//                        )
//                }
//                .buttonStyle(.plain)
                
                SecondaryButton(title: Microcopy.string(Microcopy.Key.Onboarding.ReadyToScan.ctaNotRightNow), takeFullWidth: false) {
                    onNotRightNow()
                }

                Button(action: onHaveAProduct) {
                    GreenCapsule(title: Microcopy.string(Microcopy.Key.Onboarding.ReadyToScan.ctaHaveAProduct))
                        .frame( width : 159 ,height: 52 )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
}

#Preview {
    ReadyToScanSheet(
        onBack: {},
        onNotRightNow: {},
        onHaveAProduct: {}
    )
}
