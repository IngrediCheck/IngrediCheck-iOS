import SwiftUI

struct CardCenterPreferenceData: Equatable {
    let code: String
    let center: CGFloat
}

struct CardCenterPreferenceKey: PreferenceKey {
    static var defaultValue: [CardCenterPreferenceData] = []
    
    static func reduce(value: inout [CardCenterPreferenceData], nextValue: () -> [CardCenterPreferenceData]) {
        value.append(contentsOf: nextValue())
    }
}

struct ScanCardsCarousel<CardContent: View>: View {
    let items: [String]  // IDs for items (barcodes or scanIds)
    @ViewBuilder let cardContent: (String) -> CardContent
    var scrollTargetId: String? = nil
    var onCardCenterChanged: ((String?) -> Void)? = nil
    
    @Binding var cardCenterData: [CardCenterPreferenceData]
    
    private let screenCenterX = UIScreen.main.bounds.width / 2
    private let maxDistance: CGFloat = 220
    private let minScale: CGFloat = 97.0 / 120.0
    
    var body: some View {
        ScrollViewReader { proxy in
            // Always show at least one placeholder card if items are empty
            let displayItems = items.isEmpty ? [""] : items
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(displayItems, id: \.self) { itemId in
                        GeometryReader { geo in
                            let midX = geo.frame(in: .global).midX
                            let distance = abs(midX - screenCenterX)
                            let t = min(distance / maxDistance, 1)
                            let scale = max(minScale, 1 - (1 - minScale) * t)

                            cardContent(itemId)
                                .scaleEffect(x: 1.0, y: scale, anchor: .center)
                                .animation(.easeInOut(duration: 0.2), value: scale)
                                .background(
                                    Color.clear.preference(
                                        key: CardCenterPreferenceKey.self,
                                        value: [CardCenterPreferenceData(code: itemId, center: midX)]
                                    )
                                )
                        }
                        .frame(width: 300, height: 120)
                        .id(itemId)
                        .transition(.opacity)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, max((UIScreen.main.bounds.width - 300) / 2, 0))
            }
            .scrollTargetBehavior(.viewAligned)  // Enable snap-to-center behavior
            .onChange(of: scrollTargetId) { target in
                guard let target else { return }
                withAnimation(.easeInOut) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
            .onPreferenceChange(CardCenterPreferenceKey.self) { values in
                cardCenterData = values
                let centerX = UIScreen.main.bounds.width / 2
                if let nearest = nearestCenteredCode(to: centerX, in: values) {
                    onCardCenterChanged?(nearest)
                }
            }
        }
    }
    
    private func nearestCenteredCode(to centerX: CGFloat, in values: [CardCenterPreferenceData]) -> String? {
        guard !values.isEmpty else { return nil }
        let nearest = values.min(by: { abs($0.center - centerX) < abs($1.center - centerX) })?.code
        // Filter out empty string (used for placeholder when items is empty)
        return nearest?.isEmpty == true ? nil : nearest
    }
}

