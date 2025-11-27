//
//  MemojiQuestionariesCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 01/10/25.
//

import SwiftUI

struct MemojiQuestionariesCard: View {
    struct DietaryIcon: Identifiable {
        let id = UUID()
        let imageName: String
        var isFilled: Bool
    }
    
    @State private var icons: [DietaryIcon] = [
        .init(imageName: "allergies", isFilled: true),
        .init(imageName: "mingcute_alert-line", isFilled: true),
        .init(imageName: "lucide_stethoscope", isFilled: true),
        .init(imageName: "lucide_baby", isFilled: true),
        .init(imageName: "nrk_globe", isFilled: true),
        .init(imageName: "avoid", isFilled: false),
        .init(imageName: "hugeicons_plant-01", isFilled: false),
        .init(imageName: "fluent-emoji-high-contrast_fork-and-knife-with-plate", isFilled: false),
        .init(imageName: "streamline_recycle-1-solid", isFilled: true),
        .init(imageName: "iconoir_chocolate", isFilled: true)
    ]
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("John Doe")
                    .font(ManropeFont.medium.size(14))
                    .foregroundStyle(Color(hex: "#303030"))
                
                ZStack {
                    ForEach(Array(icons.enumerated()), id: \.offset) { idx, icon in
                        questionariesIconCircle(icon: icon)
                            .offset(x: CGFloat(idx) * 26)
                            .zIndex(Double(icons.count - idx))
                    }
                }
            }
            
            Spacer()
            
            Image("memoji")
                .resizable()
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#FBFBFB"))
                .shadow(color: Color(hex: "#ECECEC"), radius: 9)
        )
    }
    
    
    @ViewBuilder
    func questionariesIconCircle(icon: DietaryIcon) -> some View {
        Circle()
            .stroke(style: StrokeStyle(lineWidth: 0.4))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                icon.isFilled ? Color(hex: "#FCF0DF") : Color(hex: "#F7F7F7"),
                in: .circle
            )
            .overlay(
                Image(icon.imageName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(icon.isFilled ? Color(hex: "#FAB222") : Color(hex: "#D3D3D3"))
                    .frame(width: 18, height: 18)
                    .padding(5)
            )
    }
}

#Preview {
//    ZStack {
//        Color.white.ignoresSafeArea()
        MemojiQuestionariesCard()
            .padding(.horizontal)
//    }
}
