//
//  IngredientsChips.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import SwiftUI

struct IngredientsChips: View {
    var title: String = "Peanuts"
    var bgColor: String = "#DDDDDD"
    var fontColor: String = "000000"
    var fontSize: CGFloat = 12
    var fontWeight: Font.Weight = .regular
    var image: String? = nil
    var familyList: [String] = []
    var onClick: (() -> Void)? = nil
    
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
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundStyle(Color(hex: fontColor))
                
                if !familyList.isEmpty {
                    HStack(spacing: -7) {
                        ForEach(familyList.prefix(4), id: \.self) { image in
                            familyIcon(image: image)
                        }
                    }
                }
            }
            .padding(.vertical, (image != nil) ? 4 : 7.5)
            .padding(.trailing, !familyList.isEmpty ? 8 : 12)
            .padding(.leading, (image != nil) ? 8 : 12)
            .background(Color(hex: bgColor), in: .capsule)
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
