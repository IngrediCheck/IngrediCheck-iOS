//
//  PrimaryButton.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 09/10/25.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let icon: String?
    var iconWidth: CGFloat = 20
    var iconHeight: CGFloat = 20
    var width: CGFloat = 152
    var height: CGFloat = 52
    var takeFullWidth: Bool = true
    var isLoading: Bool = false
    var labelFont: Font = NunitoFont.semiBold.size(16)
    var isDisabled: Bool = false
    var shadowDissabled: Bool = false
    
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
        labelFont: Font = NunitoFont.semiBold.size(16),
        shadowDissabled: Bool = false
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
        self.shadowDissabled = shadowDissabled
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
        .frame(width: takeFullWidth ? nil : width, height: height)
        .frame(minWidth: takeFullWidth ? 152 : 0)
        .frame(maxWidth: takeFullWidth ? .infinity : nil)
        .background(backgroundView)
        .overlay(
            Capsule()
                .stroke(lineWidth: 1)
                .foregroundStyle(isDisabled ? .grayScale40 : .grayScale10)
        )
        // Outer drop shadow - only when not disabled
        .shadow(
            color: (isDisabled || shadowDissabled) ? Color.clear : Color(hex: "C5C5C5").opacity(0.47),
            radius: 2.6,
            x: 0,
            y: 1
        )
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if isDisabled {
            Capsule()
                .fill(Color.grayScale40)
        } else {
            ZStack {
                // Base gradient
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "9DCF10"),
                                Color(hex: "6B8E06")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .shadow(.inner(color: Color(hex: "EDEDED").opacity(0.25), radius: 7.5, x: 2, y: 18))
                        .shadow(.inner(color: Color(hex: "72930A").opacity(1.2), radius: 5.7, x: 0, y: 0))
                        .shadow(.drop(color: Color(hex: "6B8E06").opacity(0.8), radius: 5.7, x: 0, y: 4))
                    )
                    .clipShape(Capsule())
                
                // Inset depth shadow
                Capsule()
                    .fill(Color.clear)
                    .shadow(
                        color: Color(hex: "6B8E06").opacity(0.8),
                        radius: 5.7,
                        x: 0,
                        y: 4
                    )
                    .clipShape(Capsule())
                
                // Border (will be overridden by overlay)
                Capsule()
                    .stroke(Color.white, lineWidth: 1)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.8).ignoresSafeArea()
        VStack(spacing: 20) {
            PrimaryButton(title: "Get Started")
            PrimaryButton(title: "Continue", isLoading: true)
            PrimaryButton(title: "Disabled", isDisabled: true)
            PrimaryButton(title: "With Icon", icon: "share", iconWidth: 12, iconHeight: 12)
        }
        .padding()
    }
}
