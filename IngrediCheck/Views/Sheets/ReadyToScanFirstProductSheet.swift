import SwiftUI

struct ReadyToScanSheet: View {
    let onBack: () -> Void
    let onNotRightNow: () -> Void
    let onHaveAProduct: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // CENTER TEXT
                Text("Ready to scan your ")
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
            Text("first product? ")
                .font(NunitoFont.bold.size(22))
                .foregroundStyle(.grayScale150)
                

            Text("Do you have any food product around you right now?")
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
                
                SecondaryButton(title: "Not right now", takeFullWidth: false) {
                    onNotRightNow()
                }

                Button(action: onHaveAProduct) {
                    GreenCapsule(title: "Have a product")
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
