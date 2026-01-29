import SwiftUI

struct ScanningHelpSheet: View {
    let onBack: () -> Void
    let onGotIt: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // CENTER TEXT
                Text("See how scanning works")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

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
            }
            .padding(.top, 8)

          

            Text("Here’s a quick look at how you can scan products\nwhen you’re ready.")
                .font(ManropeFont.medium.size(12))
                .foregroundStyle(.grayScale120)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            Button(action: onGotIt) {
                GreenCapsule(title: "Got it", width: 159, takeFullWidth: false)
                    .frame(width: 156, height: 52)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
}

#Preview {
    ScanningHelpSheet(onBack: {}, onGotIt: {})
}
