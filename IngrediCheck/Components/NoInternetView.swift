import SwiftUI

struct NoInternetView: View {
    var body: some View {
        ZStack {
            Color.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 60))
                    .foregroundStyle(.grayScale90)

                Text("No Internet Connection")
                    .font(ManropeFont.bold.size(18))
                    .foregroundStyle(.grayScale150)

                Text("Please check your connection and try again")
                    .font(ManropeFont.regular.size(14))
                    .foregroundStyle(.grayScale100)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    NoInternetView()
}
