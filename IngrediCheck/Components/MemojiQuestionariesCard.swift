//
//  MemojiQuestionariesCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 01/10/25.
//

import SwiftUI

struct MemojiQuestionariesCard: View {
    @State var iconsArr: [String] = [
        "allergies",
        "mingcute_alert-line",
        "lucide_stethoscope",
        "lucide_baby",
        "nrk_globe",
        "charm_circle-cross",
        "hugeicons_plant-01",
        "fluent-emoji-high-contrast_fork-and-knife-with-plate",
        "streamline_recycle-1-solid",
        "iconoir_chocolate"
    ]
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("John Doe")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(hex: "#1C1C1C"))
                
                ZStack {
                    ForEach(Array(iconsArr.enumerated()), id: \.offset) { idx, icon in
                        questionariesIconCircle(image: icon)
                            .offset(x: CGFloat(idx) * 13.5)
                            .zIndex(Double(iconsArr.count - idx))
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
        .background(Color(hex: "#FBFBFB"), in: RoundedRectangle(cornerRadius: 16))
    }
    
    
    @ViewBuilder
    func questionariesIconCircle(image: String) -> some View {
        Circle()
            .stroke(style: StrokeStyle(lineWidth: 0.25))
            .foregroundStyle(Color(hex: "#B6B6B6"))
            .frame(width: 16.5, height: 16.5)
            .background(Color(hex: "#EBEBEB"), in: .circle)
            .overlay(
                Image(image)
                    .resizable()
                    .frame(width: 10.31, height: 10.31)
            )
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        MemojiQuestionariesCard()
            .padding(.horizontal)
    }
}
