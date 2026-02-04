import SwiftUI

struct ScanningHelpSheet: View {
    let onBack: () -> Void
    let onGotIt: () -> Void

    var body: some View {
        VStack(spacing: 0) {
//            ZStack {
                // CENTER TEXT
//                Text("See how scanning works")
//                    .font(NunitoFont.bold.size(22))
//                    .foregroundStyle(.grayScale150)
//                    .multilineTextAlignment(.center)
//                    .padding(.top, 4)

//                // LEFT ICON
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
//            }
//            .padding(.top, 8)

          
            Microcopy.text(Microcopy.Key.Onboarding.ScanningHelp.subtitle)
                .font(NunitoFont.bold.size(14))
                .foregroundStyle(.grayScale150)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .lineLimit(2)

            Button(action: onGotIt) {
                GreenCapsule(title: Microcopy.string(Microcopy.Key.Common.gotIt), width: 159, takeFullWidth: false)
                    .frame(width: 156, height: 52)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
}

#Preview {
    ScanningHelpSheet(onBack: {}, onGotIt: {})
}
