//
//  Temp2.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 03/10/25.
//

import SwiftUI

struct StackedCards: View {
    @State private var cards: [Card] = [
        Card(text: "Blue", color: .blue), Card(text: "Red", color: .red), Card(text: "Yellow", color: .yellow),
        Card(text: "Green", color: .green), Card(text: "Pink", color: .pink), Card(text: "Brown", color: .brown)
    ]
    
    @State var chips: [ChipsModel] = [
        ChipsModel(name: "High Protein", icon: "chicken"),
        ChipsModel(name: "Low Carb", icon: "cucumber"),
        ChipsModel(name: "Low Fat", icon: "avacardo"),
        ChipsModel(name: "Balanced Marcos", icon: "weight-machine")
    ]
    
    @State private var dragOffset: CGSize = .zero

    private let cardSize = CGSize(width: 300, height: 200)
    private let tiltDegrees: Double = 4
    private let swapThreshold: CGFloat = 120
    private let offsetStep = CGSize(width: 10, height: 14)

    var body: some View {
        ZStack {
            // Render only the top two cards: the top is full, the second shows edges
            ForEach(Array(cards.enumerated()).suffix(2), id: \.element.id) { index, card in
                let isTop = index == cards.count - 1
                let isSecond = index == cards.count - 2
                let rotationForPosition: Double = isSecond ? tiltDegrees : 0
                let baseOffset = isSecond ? offsetStep : .zero
                
                ZStack {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Macronutrient Goals")
                                .font(.system(size: 20, weight: .regular))
                            
                            Text("Do you want to balance your proteins, carbs, and fats-or focus on one?")
                                .font(.system(size: 12, weight: .regular))
                                .opacity(0.8)
                        }
                        
                        FlowLayout(horizontalSpacing: 4, verticalSpacing: 8) {
                            ForEach(chips, id: \.id) { chip in
                                HStack {
                                    Image(chip.icon)
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                    
                                    Text(chip.name)
                                        .font(.system(size: 12, weight: .regular))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().foregroundStyle(Color(hex: "#ECECEC")))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 20)
                    .background(isTop ? Color(hex: "#D7D6D6") : Color(hex: "#E5E5E5"), in: RoundedRectangle(cornerRadius: 24))
                    
                }
                .rotationEffect(.degrees(rotationForPosition), anchor: .center)
                .offset(isTop ? dragOffset : .zero)
                .zIndex(Double(index))
                .gesture(
                    isTop ? DragGesture()
                        .onChanged { value in
                            dragOffset = CGSize(width: value.translation.width, height: 0)
                        }
                        .onEnded { value in
                            let horizontal = value.translation.width
                            let absX = abs(horizontal)
                            if absX > swapThreshold {
                                let direction: CGFloat = horizontal >= 0 ? 1 : -1
                                withAnimation(.spring()) {
                                    dragOffset = CGSize(width: direction * 600, height: 0)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    withAnimation(.spring()) {
                                        moveTopCardToBack()
                                        dragOffset = .zero
                                    }
                                }
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = .zero
                                }
                            }
                        } : nil
                )
            }
        }
        .padding(24)
    }

    private func moveTopCardToBack() {
        let top = cards.removeLast()
        cards.insert(top, at: 0)
    }
}

 struct Card: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

#Preview {
    StackedCards()
}
