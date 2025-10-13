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
                    .renderingMode(.template)
                    .foregroundStyle(.grayScale110)
                    .frame(width: 18, height: 18)
                
                Text("allergies".capitalized)
                    .font(NunitoFont.semiBold.size(14))
                    .foregroundStyle(.grayScale110)
            }
            .fontWeight(.semibold)
            
            VStack {
                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(chips, id: \.id) { chip in
                        IngredientsChips(
                            title: chip.name,
                            bgColor: .secondary200,
                            image: chip.icon,
                            outlined: false
                        )
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.white)
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 0.25)
                .foregroundStyle(.grayScale60)
        )
        
    }
}

#Preview {
    ZStack {
//        Color.gray.opacity(0.3).ignoresSafeArea()
        CanvasCard()
            .padding(.horizontal)
    }
}
