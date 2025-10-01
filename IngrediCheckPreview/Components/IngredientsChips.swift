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
    var onClick: (() -> Void)? = nil
    var image: String? = nil
    
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
            }
            .padding(.vertical, (image != nil) ? 4 : 7.5)
            .padding(.trailing, 12)
            .padding(.leading, (image != nil) ? 8 : 12)
            .background(Color(hex: bgColor), in: .capsule)
        }
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
    }
    
}
