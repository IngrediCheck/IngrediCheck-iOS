//
//  PrimaryButton.swift
//  IngrediCheck
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
    var takeFullWidth: Bool = false
    var isLoading: Bool = false
    var labelFont: Font = NunitoFont.semiBold.size(16)
    var isDisabled: Bool = false
    
    init(
        title: String,
        icon: String? = nil,
        iconWidth: CGFloat = 20,
        iconHeight: CGFloat = 20,
        width: CGFloat = 152,
        height: CGFloat = 52,
        takeFullWidth: Bool = true,
        isLoading: Bool = false,
        isDisabled: Bool = false,
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
        self.isDisabled = isDisabled
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
                    .foregroundStyle(isDisabled ? .grayScale110 : .grayScale10)
            }
        }
        // Respect explicit width/height when takeFullWidth is false, otherwise fill horizontally with a sensible min width
        .frame(width: takeFullWidth ? nil : width, height: height)
        .frame(minWidth: takeFullWidth ? 152 : 152)
        .frame(maxWidth: takeFullWidth ? .infinity : nil)
        .background(backgroundView)
        .overlay(
            Capsule()
                .stroke(lineWidth: 1)
                .foregroundStyle(isDisabled ? .grayScale40 : .grayScale10)
            
        )
//        .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if isDisabled {
            Capsule()
                .fill(
                    Color.grayScale40
                )
        } else {
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
        }
    }
}

#Preview {
    ZStack {
//        Color.gray.opacity(0.1).ignoresSafeArea()
        VStack(spacing: 20) {
            GreenCapsule(title: "Get Started")
            GreenCapsule(title: "Continue", isLoading: true)
            GreenCapsule(title: "Disabled", isDisabled: true)
            GreenCapsule(title: "With Icon", icon: "share", iconWidth: 12, iconHeight: 12)
        }
        .padding()
    }
}
