//
//  CapsuleButton.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import SwiftUI

struct CapsuleButton: View {
    
    var title: String = "Just me"
    var bgColor: String = "#EBEBEB"
    var fontColor: String = "000000"
    var fontSize: CGFloat = 14
    var fontWeight: Font.Weight = .regular
    var width: CGFloat = 120
    var height: CGFloat = 36
    var onClick: (() -> Void)? = nil
    
    
    var body: some View {
        Button {
            onClick?()
        } label: {
            Text(title)
                .font(.system(size: fontSize, weight: fontWeight))
                .foregroundStyle(Color(hex: fontColor))
                .frame(width: width, height: height)
                .background(Color(hex: bgColor), in: .capsule)
        }
    }
}

#Preview {
    CapsuleButton()
}
