//
//  IngredientsChips.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import SwiftUI

struct IngredientsChips: View {
    var title: String = "Peanuts"
    @State var bgColor: Color? = nil
    var fontColor: String = "000000"
    var fontSize: CGFloat = 12
    var fontWeight: Font.Weight = .regular
    var image: String? = nil
    var familyList: [String] = []
    var onClick: (() -> Void)? = nil
    var isSelected: Bool = false
    var outlined: Bool = true
    
    var body: some View {
        Button {
            onClick?()
        } label: {
            HStack(spacing: 8) {
                if let image = image {
                    Text(image)
                        .font(.system(size: 18))
                        .frame(width: 24, height: 24)
                }
                
                Text(familyList.isEmpty ? title : String(title.prefix(25)) + (title.count > 25 ? "..." : ""))
                    .font(ManropeFont.medium.size(14))
                    .foregroundStyle(isSelected ? .primary100 : Color(hex: fontColor))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if !familyList.isEmpty {
                    HStack(spacing: -7) {
                        ForEach(familyList.prefix(4), id: \.self) { image in
                            familyIcon(image: image)
                        }
                    }
                }
            }
            .padding(.vertical, (image != nil) ? 6 : 7.5)
            .padding(.trailing, !familyList.isEmpty ? 8 : 16)
            .padding(.leading, (image != nil) ? 12 : 16)
            .background(
                (bgColor != nil)
                ? LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: bgColor ?? .white, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                : isSelected
                    ? LinearGradient(
                        colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    : LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                , in: .capsule
            )
            .overlay(
                Capsule()
                    .stroke(lineWidth: (isSelected || outlined == false) ? 0 : 1)
                    .foregroundStyle(.grayScale60)
            )
        }
    }
    
    @ViewBuilder
    func familyIcon(image: String) -> some View {
        Circle()
            .stroke(lineWidth: 1)
            .frame(width: 24, height: 24)
            .foregroundStyle(Color(hex: "#B6B6B6"))
            .background(Color(hex: "#D9D9D9"))
            .overlay(
                Image(image)
                    .resizable()
                    .frame(width: 24, height: 24)
            )
    }

}

#Preview {
    VStack {
        IngredientsChips(
            title: "Peanuts",
            image: "🥜"
        )
        IngredientsChips(
            title: "Sellfish",
            image: "🦐"
        )
        IngredientsChips(
            title: "Wheat",
            image: "🌾"
        )
        IngredientsChips(
            title: "Sesame",
            image: "❤️"
        )
        IngredientsChips(title: "India & South Asia")
        IngredientsChips(
            title: "Peanuts",
            image: "🥜",
            familyList: ["image 1", "image 2", "image 3"]
        )
    }
    
}
