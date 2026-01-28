import SwiftUI

/// Reusable legal disclaimer view with Terms of Use and Privacy Policy links
struct LegalDisclaimerView: View {
    var showShieldIcon: Bool = true

    private let termsURL = "https://www.ingredicheck.app/terms-conditions"
    private let privacyURL = "https://www.ingredicheck.app/privacy-policy"

    var body: some View {
        HStack {
            if showShieldIcon {
                Image("jam-sheld-half")
                    .frame(width: 16, height: 16)
            }
            Text("Review my **[Terms of Use](\(termsURL))** and **[Privacy Policy](\(privacyURL))**.")
                .multilineTextAlignment(.center)
                .font(showShieldIcon ? ManropeFont.regular.size(12) : .footnote)
                .tint(.paletteAccent)
                .foregroundStyle(showShieldIcon ? Color.grayScale100 : .primary)
        }
    }
}

#Preview("With Shield Icon") {
    LegalDisclaimerView(showShieldIcon: true)
}

#Preview("Without Shield Icon") {
    LegalDisclaimerView(showShieldIcon: false)
}
