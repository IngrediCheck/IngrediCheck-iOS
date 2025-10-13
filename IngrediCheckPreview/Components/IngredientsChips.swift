//
//  IngredientsChips.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import SwiftUI

struct IngredientsChips: View {
    var title: String = "Peanuts"
    var bgColor: Color? = .white
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
                    Image(image)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                
                Text(title)
                    .font(ManropeFont.medium.size(14))
                    .foregroundStyle(isSelected ? .primary100 : Color(hex: fontColor))
                
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
                        gradient: Gradient(stops: [
                            .init(color: Color(hex: "9DCF10"), location: 0.0),
                            .init(color: Color(hex: "6B8E06"), location: 0.87)
                        ]),
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
            image: "peanut"
        )
        IngredientsChips(
            title: "Sellfish",
            image: "sellfish"
        )
        IngredientsChips(
            title: "Wheat",
            image: "wheat"
        )
        IngredientsChips(
            title: "Sesame",
            image: "sesame"
        )
        IngredientsChips(title: "India & South Asia")
        IngredientsChips(
            title: "Peanuts",
            image: "peanut",
            familyList: ["image 1", "image 2", "image 3"]
        )
    }
    
}
