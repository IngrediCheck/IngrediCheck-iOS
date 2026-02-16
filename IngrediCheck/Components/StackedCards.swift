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
    var isFallback: Bool = false
}

struct StackedCards: View {
    
    var isChipSelected: (Card, ChipsModel) -> Bool
    var onChipTap: (Card, ChipsModel) -> Void
    var onSwipe: (() -> Void)? = nil
    
    @State private var cards: [Card]
    @State private var currentIndex: Int = 0
    private let totalCardCount: Int
    @State var dragOffset: CGSize = .zero
    @State var dragValue: CGFloat = 0
    @State var tempCard: Card = Card(title: "", subTitle: "", color: .black, chips: [])
    private var progressText: String {
        totalCardCount > 0 ? "\(currentIndex)/\(totalCardCount)" : ""
    }
    
    init(
        cards: [Card],
        isChipSelected: @escaping (Card, ChipsModel) -> Bool = { _, _ in false },
        onChipTap: @escaping (Card, ChipsModel) -> Void = { _, _ in },
        onSwipe: (() -> Void)? = nil
    ) {
        var augmentedCards = cards
        let fallbackCard = Card(
            title: "Did we miss something?",
            subTitle: "No worries! You can share any preferences later, we’ve got you covered.",
            color: Color(hex: "#D7EEB2"),
            chips: [],
            isFallback: true
        )
        augmentedCards.append(fallbackCard)

        self._cards = State(initialValue: augmentedCards)
        self._currentIndex = State(initialValue: augmentedCards.isEmpty ? 0 : 1)
        self.totalCardCount = augmentedCards.count
        self.isChipSelected = isChipSelected
        self.onChipTap = onChipTap
        self.onSwipe = onSwipe
    }
    
    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()).prefix(2).reversed(), id: \.element.id) {
                idx,
                card in
                ZStack {
                    VStack(alignment: .leading, spacing: 20) {
                        if card.isFallback {
                            ZStack {
                                VStack(spacing: 6) {
                                    Image("Questionmark-bot")
                                    
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 110, height: 107)

                                    Text(card.title)
                                        .font(ManropeFont.extraBold.size(18))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text(card.subTitle)
                                        .font(ManropeFont.regular.size(12))
                                        .opacity(0.8)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                                VStack {
                                    HStack {
                                        Spacer()
                                        Text(progressText)
                                            .font(ManropeFont.regular.size(14))
                                            .foregroundColor(.grayScale140)
                                    }
                                    Spacer()
                                }
                            }
                            .opacity((idx == 0) ? 1 : 0)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(){
                                    Text(card.title)
                                        .font(.system(size: 20, weight: .regular))
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    Text(progressText)
                                        .font(ManropeFont.regular.size(14))
                                        .foregroundColor(.grayScale140)
                                }
                                
                                Text(card.subTitle)
                                    .font(.system(size: 12, weight: .regular))
                                    .opacity(0.8)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .opacity((idx == 0) ? 1 : 0)

                            ScrollView(.vertical, showsIndicators: true) {
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
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .opacity((idx == 0) ? 1 : 0)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 20)
                    .frame(height: UIScreen.main.bounds.height * 0.33, alignment: .topLeading)
                    .background(
                        ZStack {
                            (idx == 0 ? card.color : tempCard.color)

                            if idx == 0 {
                                if card.isFallback {
                                    VStack {
                                        HStack {
                                            Image("circle-cards")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 183, height: 248)
                                                .opacity(0.85)
                                                .offset(x: -51 , y: -77)
                                            
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                    .padding(.leading, 0)
                                    .padding(.top, 0)

                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            Image("circle-cards")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 197, height: 241)
                                                .opacity(0.55)
                                                .offset(x: 77, y: 51)
                                              
                                        }
                                    }
                                    .padding(.trailing, 0)
                                    .padding(.bottom, 0)
                                } else {
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            Image("leaf-recycle")
                                                .opacity(0.5)
                                        }
                                    }
                                    .padding(.trailing, 10)
                                    .offset(y: 17)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    )
                }
                .blur(radius: (idx == 0) ? 0 : 4)
                .opacity((idx == 0) ? 1 : 0.52)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .rotationEffect(.degrees((idx == 0) ? 0 : 4))
                .offset(x: (idx == 0) ? dragOffset.width : 0, y: (idx == 0) ? dragOffset.height : 0)
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard idx == 0 else { return }

                            let horizontalTranslation = value.translation.width
                            let verticalTranslation = value.translation.height
                            guard abs(horizontalTranslation) > abs(verticalTranslation) else { return }

                            dragOffset.width = horizontalTranslation
                            dragOffset.height = 0

                            dragValue = horizontalTranslation
                        }
                        .onEnded { _ in
                            guard idx == 0 else { return }
                            
                            withAnimation(.smooth) {
                                dragOffset = .zero
                                
                                if dragValue > 80 {
                                    right()
                                    onSwipe?()
                                }
                                
                                if dragValue < -80 {
                                    left()
                                    onSwipe?()
                                }
                                
                                dragValue = 0
                            }
                        }
                )
            }
        }
        .onAppear() {
            guard cards.indices.contains(1) else { return }
            if cards.indices.contains(1) {
                tempCard = cards[1]

                cards[1].title = cards[0].title
                cards[1].subTitle = cards[0].subTitle
                cards[1].chips = cards[0].chips
                cards[1].color = cards[0].color
            }
        }
    }
    
    func left() {
        withAnimation(.smooth) {
            dragOffset.width = -600
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            resetCardPositionAndMove()
        }
    }
    
    func right() {
        withAnimation(.smooth) {
            dragOffset.width = 600
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            resetCardPositionAndMove()
        }
    }
    
    func resetCardPositionAndMove() {
        withAnimation(.smooth) {
            dragOffset = .zero
            addToLast()
            if totalCardCount > 0 {
                currentIndex = (currentIndex % totalCardCount) + 1
            }

            cards[0].title = tempCard.title
            cards[0].subTitle = tempCard.subTitle
            cards[0].chips = tempCard.chips
            cards[0].color = tempCard.color
            
            tempCard.title = cards[1].title
            tempCard.subTitle = cards[1].subTitle
            tempCard.chips = cards[1].chips
            tempCard.color = cards[1].color
            
            cards[1].title = cards[0].title
            cards[1].subTitle = cards[0].subTitle
            cards[1].chips = cards[0].chips
            cards[1].color = cards[0].color
        }
    }
    
    func addToLast() {
        guard !cards.isEmpty else { return }
        let temp = cards.removeFirst()
        cards.append(temp)
    }
}

#Preview {
    StackedCards(cards: [
        Card(
            title: "one",
            subTitle: "This is the dummy sub-title, and this is the first text",
            color: .purple,
            chips: [ChipsModel(name: "High Protein", icon: "🍗"),
                    ChipsModel(name: "Low Carb", icon: "🥒"),
                    ChipsModel(name: "Low Fat", icon: "🥑"),
                    ChipsModel(name: "Balanced Marcos", icon: "⚖️")],
        ),
        Card(
            title: "two",
            subTitle: "This is the dummy sub-title, and this is the first text",
            color: .yellow,
            chips: [ChipsModel(name: "High Protein", icon: "🍗"),
                    ChipsModel(name: "Low Carb", icon: "🥒"),
                    ChipsModel(name: "Low Fat", icon: "🥑"),
                    ChipsModel(name: "Balanced Marcos", icon: "⚖️"),
                    ChipsModel(name: "High Protein", icon: "🍗"),
                    ChipsModel(name: "Low Carb", icon: "🥒"),
                    ChipsModel(name: "Low Fat", icon: "🥑"),
                    ChipsModel(name: "Balanced Marcos", icon: "⚖️")],
        ),
        Card(
            title: "three",
            subTitle: "This is the dummy sub-title, and this is the first text hughwrhugw oighwioghiowhgo woihgiowhgiow oigwhioghwiog owirhgiorwhgiowrh woighiowrhgiowrg oighrwioghiorwhgiohrwg",
            color: .pink,
            chips: [ChipsModel(name: "High Protein", icon: "🍗"),
                    ChipsModel(name: "Low Carb", icon: "🥒"),
                    ChipsModel(name: "Low Fat", icon: "🥑"),
                    ChipsModel(name: "Balanced Marcos", icon: "⚖️")],
        ),
        Card(
            title: "four",
            subTitle: "This is the dummy sub-title, and this is the first text",
            color: .orange,
            chips: [ChipsModel(name: "High Protein", icon: "🍗"),
                    ChipsModel(name: "Low Carb", icon: "🥒"),
                    ChipsModel(name: "Low Fat", icon: "🥑"),
                    ChipsModel(name: "Balanced Marcos", icon: "⚖️")],
        ),
        Card(
            title: "five",
            subTitle: "This is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first textThis is the dummy sub-title, and this is the first text",
            color: .green,
            chips: [ChipsModel(name: "High Protein", icon: "🍗"),
                    ChipsModel(name: "Low Carb", icon: "🥒"),
                    ChipsModel(name: "Low Fat", icon: "🥑"),
                    ChipsModel(name: "Balanced Marcos", icon: "⚖️")],
        ),
        Card(
            title: "six",
            subTitle: "This is the dummy sub-title, and this is the first text",
            color: .blue,
            chips: [ChipsModel(name: "High Protein", icon: "🍗"),
                    ChipsModel(name: "Low Carb", icon: "🥒"),
                    ChipsModel(name: "Low Fat", icon: "🥑"),
                    ChipsModel(name: "Balanced Marcos", icon: "⚖️"),
                    ChipsModel(name: "High Protein", icon: "🍗"),
                    ChipsModel(name: "Low Carb", icon: "🥒"),
                    ChipsModel(name: "Low Fat", icon: "🥑"),
                    ChipsModel(name: "Balanced Marcos", icon: "⚖️"),
                    ChipsModel(name: "High Protein", icon: "🍗"),
                    ChipsModel(name: "Low Carb", icon: "🥒"),
                    ChipsModel(name: "Low Fat", icon: "🥑")],
        )
    ])
        .padding()
}
