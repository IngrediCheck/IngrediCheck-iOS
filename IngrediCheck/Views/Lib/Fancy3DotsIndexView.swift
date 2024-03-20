// Credit: https://betterprogramming.pub/custom-paging-ui-in-swiftui-13f1347cf529

import SwiftUI

struct Fancy3DotsIndexView: View {
  
    let numberOfPages: Int
    let currentIndex: Int

    private let circleSize: CGFloat = 12
    private let circleSpacing: CGFloat = 10

    private let primaryColor = Color.white
    private let secondaryColor = Color.white.opacity(0.6)

    private let smallScale: CGFloat = 0.6

    var body: some View {
      HStack(spacing: circleSpacing) {
          ForEach(0..<numberOfPages, id:\.self) { index in
              if shouldShowIndex(index) {
                  Circle()
                  .fill(.paletteAccent)
                  .scaleEffect(currentIndex == index ? 1 : smallScale)
                  .frame(width: circleSize, height: circleSize)
                  .transition(AnyTransition.opacity.combined(with: .scale))
                  .id(index)
              }
          }
      }
    }

    func shouldShowIndex(_ index: Int) -> Bool {
        ((currentIndex - 2)...(currentIndex + 2)).contains(index)
    }
}
