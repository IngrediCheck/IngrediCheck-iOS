import SwiftUI

struct ThreeDotsIndexView: View {
  
    let numberOfPages: Int
    let currentIndex: Int

    private let numberOfDots: Int = 3
    private let circleSize: CGFloat = 10
    private let circleSpacing: CGFloat = 10

    private let primaryColor = Color.white
    private let secondaryColor = Color.white.opacity(0.6)

    private let smallScale: CGFloat = 0.6

    var body: some View {
      HStack(spacing: circleSpacing) {
          ForEach(0..<numberOfDots, id:\.self) { index in
              Circle()
                  .fill(isCurrent(index) ? .paletteAccent : .gray.opacity(0.5))
                  .frame(width: circleSize, height: circleSize)
                  .transition(AnyTransition.opacity.combined(with: .scale))
                  .id(index)
          }
      }
    }
    
    private func isCurrent(_ dotIndex: Int) -> Bool {
        if currentIndex == 0 {
            return dotIndex == 0
        } else if currentIndex == (numberOfPages - 1) {
            return dotIndex == 2
        } else {
            return dotIndex == 1
        }
    }
}
