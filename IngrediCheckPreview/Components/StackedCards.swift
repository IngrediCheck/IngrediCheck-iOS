//
//  Temp2.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 03/10/25.
//

import SwiftUI

struct Card: Identifiable, Equatable {
    var id = UUID().uuidString
    var title: String
    var subTitle: String
    var color: Color
    var chips: [ChipsModel]
}

struct StackedCards: View {
    
    var isChipSelected: (Card, ChipsModel) -> Bool
    var onChipTap: (Card, ChipsModel) -> Void
    
    /// Immutable list of cards.
    private let cards: [Card]
    
    /// Index of the currently visible (front) card.
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    
    init(
        cards: [Card],
        isChipSelected: @escaping (Card, ChipsModel) -> Bool = { _, _ in false },
        onChipTap: @escaping (Card, ChipsModel) -> Void = { _, _ in }
    ) {
        self.cards = cards
        self.isChipSelected = isChipSelected
        self.onChipTap = onChipTap
    }
    
    var body: some View {
        let cardHeight = UIScreen.main.bounds.height * 0.33
        
        return ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let isFront = index == currentIndex
                let isSecond = cards.count > 1 && index == (currentIndex + 1) % cards.count
                
                cardContent(for: card)
                    .frame(maxWidth: .infinity,
                           maxHeight: cardHeight,
                           alignment: .top)
                    .background(card.color, in: RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        Image(.leafRecycle)
                            .opacity(0.5)
                            .offset(y: 17)
                            .padding(.trailing, 10)
                            .clipped()
                        , alignment: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .rotationEffect(
                        isFront
                        ? .degrees(Double(max(min(dragOffset.width / 25, 12), -12)))
                        : (isSecond ? .degrees(4) : .degrees(0))
                    )
                    .offset(x: isFront ? dragOffset.width : 0, y: 0)
                    .opacity(isFront || isSecond ? 1 : 0)
                    .zIndex(isFront ? 1 : 0)
                    .allowsHitTesting(isFront)
                    .highPriorityGesture(dragGesture)
                    
            }
        }
        .animation(.smooth(duration: 0.25), value: currentIndex)
        .frame(height: cardHeight, alignment: .top)
    }
    
    // MARK: - Navigation
    
    private func goToNext() {
        guard !cards.isEmpty else { return }
        currentIndex = (currentIndex + 1) % cards.count
    }
    
    private func goToPrevious() {
        guard !cards.isEmpty else { return }
        currentIndex = (currentIndex - 1 + cards.count) % cards.count
    }
    
    // MARK: - Gestures
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset.width = value.translation.width
            }
            .onEnded { value in
                let translation = value.translation.width
                let threshold: CGFloat = 150
                let screenWidth = UIScreen.main.bounds.width
                
                if translation < -threshold {
                    // Throw card to the left, then promote next card
                    withAnimation(.smooth(duration: 0.25)) {
                        dragOffset.width = -screenWidth
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.smooth(duration: 0.25)) {
                            goToNext()
                            dragOffset = .zero
                        }
                    }
                } else if translation > threshold {
                    // Throw card to the right, then promote previous card
                    withAnimation(.smooth(duration: 0.25)) {
                        dragOffset.width = screenWidth
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.smooth(duration: 0.25)) {
                            goToPrevious()
                            dragOffset = .zero
                        }
                    }
                } else {
                    // Not enough swipe: snap back
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        dragOffset = .zero
                    }
                }
            }
    }
    
    @ViewBuilder
    private func cardContent(for card: Card) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.system(size: 20, weight: .regular))
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(card.subTitle)
                    .font(.system(size: 12, weight: .regular))
                    .opacity(0.8)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            FlowLayout(horizontalSpacing: 4, verticalSpacing: 8) {
                ForEach(card.chips, id: \.id) { chip in
                    IngredientsChipsForStackedCards(
                        title: chip.name,
                        bgColor: nil,
                        fontColor: "303030",
                        image: chip.icon ?? "",
                        onClick: {
                            onChipTap(card, chip)
                        },
                        isSelected: isChipSelected(card, chip),
                        outlined: false
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 20)
    }
}

#Preview {
    StackedCards(cards: [
        Card(
            title: "one",
            subTitle: "This is the dummy sub-title, and this is the first text",
            color: .purple,
            chips: [ChipsModel(name: "High Protein", icon: "chicken"),
                    ChipsModel(name: "Low Carb", icon: "Cucumber"),
                    ChipsModel(name: "Low Fat", icon: "Avacardo"),
                    ChipsModel(name: "Balanced Marcos", icon: "weight-machine")],
        ),
        Card(
            title: "two",
            subTitle: "This is the dummy sub-title, and this is the first text",
            color: .yellow,
            chips: [ChipsModel(name: "High Protein", icon: "chicken"),
                    ChipsModel(name: "Low Carb", icon: "Cucumber"),
                    ChipsModel(name: "Low Fat", icon: "Avacardo"),
                    ChipsModel(name: "Balanced Marcos", icon: "weight-machine"),
                    ChipsModel(name: "High Protein", icon: "chicken"),
                    ChipsModel(name: "Low Carb", icon: "Cucumber"),
                    ChipsModel(name: "Low Fat", icon: "Avacardo"),
                    ChipsModel(name: "Balanced Marcos", icon: "weight-machine")],
        ),
        Card(
            title: "three",
            subTitle: "This is the dummy sub-title, and this is the first text hughwrhugw oighwioghiowhgo woihgiowhgiow oigwhioghwiog owirhgiorwhgiowrh woighiowrhgiowrg oighrwioghiorwhgiohrwg",
            color: .pink,
            chips: [ChipsModel(name: "High Protein", icon: "chicken"),
                    ChipsModel(name: "Low Carb", icon: "Cucumber"),
                    ChipsModel(name: "Low Fat", icon: "Avacardo"),
                    ChipsModel(name: "Balanced Marcos", icon: "weight-machine")],
        ),
        Card(
            title: "four",
            subTitle: "This is the dummy sub-title, and this is the first text",
            color: .orange,
            chips: [ChipsModel(name: "High Protein", icon: "chicken"),
                    ChipsModel(name: "Low Carb", icon: "Cucumber"),
                    ChipsModel(name: "Low Fat", icon: "Avacardo"),
                    ChipsModel(name: "Balanced Marcos", icon: "weight-machine")],
        ),
        Card(
            title: "five",
            subTitle: "This is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first text",
            color: .green,
            chips: [ChipsModel(name: "High Protein", icon: "chicken"),
                    ChipsModel(name: "Low Carb", icon: "Cucumber"),
                    ChipsModel(name: "Low Fat", icon: "Avacardo"),
                    ChipsModel(name: "Balanced Marcos", icon: "weight-machine")],
        ),
        Card(
            title: "six",
            subTitle: "This is the dummy sub-title, and this is the first text",
            color: .blue,
            chips: [ChipsModel(name: "High Protein", icon: "chicken"),
                    ChipsModel(name: "Low Carb", icon: "Cucumber"),
                    ChipsModel(name: "Low Fat", icon: "Avacardo"),
                    ChipsModel(name: "Balanced Marcos", icon: "weight-machine"),
                    ChipsModel(name: "High Protein", icon: "chicken"),
                    ChipsModel(name: "Low Carb", icon: "Cucumber"),
                    ChipsModel(name: "Low Fat", icon: "Avacardo"),
                    ChipsModel(name: "Balanced Marcos", icon: "weight-machine"),
                    ChipsModel(name: "High Protein", icon: "chicken"),
                    ChipsModel(name: "Low Carb", icon: "Cucumber"),
                    ChipsModel(name: "Low Fat", icon: "Avacardo")],
        )
    ])
        .padding()
}
