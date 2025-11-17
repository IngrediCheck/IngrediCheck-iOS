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
    
    @State private var cards: [Card]
    @State var dragOffset: CGSize = .zero
    @State var dragValue: CGFloat = 0
    @State var tempCard: Card = Card(title: "", subTitle: "", color: .black, chips: [])
    
    init(
        cards: [Card],
        isChipSelected: @escaping (Card, ChipsModel) -> Bool = { _, _ in false },
        onChipTap: @escaping (Card, ChipsModel) -> Void = { _, _ in }
    ) {
        self._cards = State(initialValue: cards)
        self.isChipSelected = isChipSelected
        self.onChipTap = onChipTap
    }
    
    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()).prefix(2).reversed(), id: \.element.id) {
                idx,
                card in
                ZStack {
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
                        .opacity((idx == 0) ? 1 : 0)
                        
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
                        .opacity((idx == 0) ? 1 : 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 20)
                    .background((idx == 0) ? card.color : tempCard.color, in: RoundedRectangle(cornerRadius: 24))
                }
                .blur(radius: (idx == 0) ? 0 : 4)
                .opacity((idx == 0) ? 1 : 0.52)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .rotationEffect(.degrees((idx == 0) ? 0 : 4))
                .offset(x: (idx == 0) ? dragOffset.width : 0, y: (idx == 0) ? dragOffset.height : 0)
                .gesture(
                    (idx == 0) ?
                    DragGesture()
                        .onChanged({ value in
                            dragOffset.width = value.translation.width
                            dragOffset.height = 0
                            
                            dragValue = value.translation.width
                        })
                        .onEnded({ value in
                            withAnimation(.smooth) {
                                dragOffset = .zero
                                
                                if dragValue > 150 {
                                    right()
                                }
                                
                                if dragValue < -150 {
                                    left()
                                }
                                
                                
                                dragValue = 0
                            }
                        })
                    : nil
                )
            }
        }
        .onAppear() {
            tempCard = cards[1]
            
            cards[1].title = cards[0].title
            cards[1].subTitle = cards[0].subTitle
            cards[1].chips = cards[0].chips
            cards[1].color = cards[0].color
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
        let temp = cards[0]
        cards.removeFirst()
        cards.append(temp)
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
