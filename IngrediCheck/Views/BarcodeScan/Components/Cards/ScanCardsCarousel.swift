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
                        cardContent(itemId)
                            .frame(width: 300, height: 120)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: CardCenterPreferenceKey.self,
                                        value: [CardCenterPreferenceData(code: itemId, center: geo.frame(in: .global).midX)]
                                    )
                                }
                            )
                            .scrollTransition(.interactive.threshold(.visible(0.5))) { content, phase in
                                content
                                    .scaleEffect(
                                        x: 1.0,
                                        y: phase.isIdentity ? 1.0 : max(minScale, 1.0 - (1.0 - minScale) * abs(phase.value)),
                                        anchor: .center
                                    )
                            }
                            .id(itemId)
                    }
                }
                .animation(.none, value: displayItems)
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

// MARK: - Previews

#if DEBUG
struct ScanCardsCarouselPreview: View {
    @State private var cardCenterData: [CardCenterPreferenceData] = []
    @State private var centeredId: String? = nil
    
    let items: [String]
    
    var body: some View {
        VStack {
            Text("Centered: \(centeredId ?? "none")")
                .font(.caption)
                .foregroundStyle(.gray)
            
            ScanCardsCarousel(
                items: items,
                cardContent: { itemId in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            VStack {
                                Text(itemId.isEmpty ? "Placeholder" : "Card: \(itemId)")
                                    .font(.headline)
                                Text("Sample card content")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        )
                },
                onCardCenterChanged: { id in
                    centeredId = id
                },
                cardCenterData: $cardCenterData
            )
        }
    }
}

#Preview("Empty State") {
    ScanCardsCarouselPreview(items: [])
}

#Preview("Single Card") {
    ScanCardsCarouselPreview(items: ["item-1"])
}

#Preview("Multiple Cards") {
    ScanCardsCarouselPreview(items: ["item-1", "item-2", "item-3", "item-4", "item-5"])
}
#endif
