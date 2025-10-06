//
//  Temp3.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 03/10/25.
//

import SwiftUI

struct Temp3: View {
    
    @State private var cards: [Card] = [
        Card(text: "Blue", color: .blue), Card(text: "Red", color: .red), Card(text: "Yellow", color: .yellow),
        Card(text: "Green", color: .green), Card(text: "Pink", color: .pink), Card(text: "Brown", color: .brown)
    ]
    
    @State var chips: [ChipsModel] = [
        ChipsModel(name: "High Protein", icon: "chicken"),
        ChipsModel(name: "Low Carb", icon: "cucumber"),
        ChipsModel(name: "Low Fat", icon: "avacardo"),
        ChipsModel(name: "Balanced Marcos", icon: "weight-machine"),
        ChipsModel(name: "High Protein", icon: "chicken"),
        ChipsModel(name: "Low Carb", icon: "cucumber"),
        ChipsModel(name: "Low Fat", icon: "avacardo"),
        ChipsModel(name: "Balanced Marcos", icon: "weight-machine")
    ]
    
    var body: some View {
        ZStack {
            
            VStack(alignment: .leading) {
                Text("Macronutrient Goals")
                    .font(.system(size: 20, weight: .regular))
                
                Text("Do you want to balance your proteins, carbs, and fats-or focus on one?")
                    .font(.system(size: 12, weight: .regular))
                    .opacity(0.8)
                
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
            .background(Color(hex: "#D7D6D6"), in: RoundedRectangle(cornerRadius: 16))
            
        }
    }
}

#Preview {
    Temp3()
}
