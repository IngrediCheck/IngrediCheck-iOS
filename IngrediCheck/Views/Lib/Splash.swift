import SwiftUI

struct Splash<Splash: View, Content: View>: View {

    var splashDuration: CGFloat = 1.0
    var splash: Splash
    var content: Content

    @State var showingSplash: Bool = true

    init(@ViewBuilder splash: () -> Splash,
         @ViewBuilder content: () -> Content) {
        self.splash = splash()
        self.content = content()
    }

    var body: some View {
        Group {
            if showingSplash {
                splash
                    .onAppear { scheduleHideSplash() }
                    .transition(.opacity.animation(.easeInOut))
            } else {
                content
                    .transition(.opacity.animation(.easeInOut))
            }
        }
    }

    func scheduleHideSplash() {
        DispatchQueue.main
            .asyncAfter(deadline: .now() + Double(splashDuration)) {
                withAnimation {
                    showingSplash = false
                }
            }
    }
}
