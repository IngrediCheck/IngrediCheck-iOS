//
//  GetStarted.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 09/10/25.
//

import SwiftUI

struct GreenCapsule: View {
    let title: String
    let icon: String?
    var iconWidth: CGFloat = 20
    var iconHeight: CGFloat = 20
    var width: CGFloat = 152
    var height: CGFloat = 52
    var takeFullWidth: Bool = true
    var isLoading: Bool = false
    var labelFont: Font = NunitoFont.semiBold.size(16)
    
    init(
        title: String,
        icon: String? = nil,
        iconWidth: CGFloat = 20,
        iconHeight: CGFloat = 20,
        width: CGFloat = 152,
        height: CGFloat = 52,
        takeFullWidth: Bool = true,
        isLoading: Bool = false,
        labelFont: Font = NunitoFont.semiBold.size(16)
    ) {
        self.title = title
        self.icon = icon
        self.iconWidth = iconWidth
        self.iconHeight = iconHeight
        self.width = width
        self.height = height
        self.takeFullWidth = takeFullWidth
        self.isLoading = isLoading
        self.labelFont = labelFont
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .grayScale10))
                    .scaleEffect(0.8)
            } else {
                if let icon {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .foregroundStyle(.white)
                        .frame(width: iconWidth, height: iconHeight)
                }
                
                Text(title)
                    .font(labelFont)
                    .foregroundStyle(.grayScale10)
            }
        }
        // Respect explicit width/height when takeFullWidth is false, otherwise fill horizontally with a sensible min width
        .frame(width: takeFullWidth ? nil : width, height: height)
        .frame(minWidth: takeFullWidth ? 152 : 0)
        .frame(maxWidth: takeFullWidth ? .infinity : nil)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .shadow(.inner(color: Color(hex: "EDEDED").opacity(0.25), radius: 7.5, x: 2, y: 9))
                    .shadow(.inner(color: Color(hex: "72930A"), radius: 5.7, x: 0, y: 4))
                    .shadow(
                        .drop(color: Color(hex: "C5C5C5").opacity(0.57), radius: 11, x: 0, y: 4)
                    )
                )
        )
        .overlay(
            Capsule()
                .stroke(lineWidth: 1)
                .foregroundStyle(.grayScale10)
            
        )
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        GreenCapsule(title: "Get Started")
    }
}
