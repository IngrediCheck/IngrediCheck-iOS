
import SwiftUI

struct ReadyToScanCanvas: View {
    var body: some View {
        VStack (spacing : 0){
          
            Microcopy.text(Microcopy.Key.Onboarding.ReadyToScanCanvas.title)
                .font(ManropeFont.bold.size(16))
                .foregroundStyle(Color.grayScale150)
                
                .padding(.top ,34)
            Microcopy.text(Microcopy.Key.Onboarding.ReadyToScanCanvas.subtitle)
                .font(ManropeFont.regular.size(13))
                .foregroundStyle(Color.grayScale100)
             
            Image("Iphone-product-image")
                .resizable()
                .scaledToFit()
                .frame(maxWidth : .infinity)
                .frame(height: 494)
            

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
    }
}

#Preview {
    ReadyToScanCanvas()
}

