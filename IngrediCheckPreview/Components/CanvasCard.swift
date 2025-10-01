//
//  CanvasCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import SwiftUI

struct CanvasCard: View {
    
    @State var chips: [ChipsModel] = [
        ChipsModel(name: "Peanuts", icon: "peanut"),
        ChipsModel(name: "Sesame", icon: "sesame"),
        ChipsModel(name: "Wheat", icon: "wheat"),
        ChipsModel(name: "Sellfish", icon: "sellfish")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image("allergies")
                    .resizable()
                    .frame(width: 18, height: 18)
                
                Text("allergies".uppercased())
                    .font(.system(size: 12))
            }
            .fontWeight(.semibold)
            
            VStack {
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
                        .background(Capsule().fill(Color(hex: "#DDDDDD")))
                    }
                }
            }
            
            HStack(spacing: 0) {
                Image("exlamation")
                    .resizable()
                    .frame(width: 24, height: 24)
                
                Text("Something else too, don't worry we'll ask later!")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#7F7F7F"))
                    .italic()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        CanvasCard()
            .padding(.horizontal)
    }
}
