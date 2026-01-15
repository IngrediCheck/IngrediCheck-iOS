//
//  SecondaryButton.swift
//  IngrediCheck
//
//  Created on 31/12/25.
//

import SwiftUI

struct SecondaryButton: View {
    let title: String
    let icon: String?
    var iconWidth: CGFloat = 20
    var iconHeight: CGFloat = 20
    var width: CGFloat = 159
    var height: CGFloat = 52
    var takeFullWidth: Bool = true
    var isLoading: Bool = false
    var labelFont: Font = NunitoFont.semiBold.size(16)
    var isDisabled: Bool = false
    let action: () -> Void
    
    init(
        title: String,
        icon: String? = nil,
        iconWidth: CGFloat = 20,
        iconHeight: CGFloat = 20,
        width: CGFloat = 159,
        height: CGFloat = 52,
        takeFullWidth: Bool = true,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        labelFont: Font = NunitoFont.semiBold.size(16),
        action: @escaping () -> Void = {}
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
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#75990E")))
                    .scaleEffect(0.8)
            } else {
                if let icon {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .foregroundStyle(isDisabled ? .grayScale110 : Color(hex: "#75990E"))
                        .frame(width: iconWidth, height: iconHeight)
                }
                
                Text(title)
                    .font(labelFont)
                    .foregroundStyle(isDisabled ? .grayScale110 : Color(hex: "#75990E"))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 14)
//        .padding(.horizontal, 37)
        .frame(height: height)
        .frame(minWidth: takeFullWidth ? 159 : width)
        .frame(maxWidth: takeFullWidth ? .infinity : nil)
        .background(backgroundView)
        .overlay(
            Capsule()
                .strokeBorder(
                    Color.grayScale40,
                    lineWidth: 1.5
                )
        )
//        .overlay(borderView, alignment: .center)
//        .opacity(isDisabled ? 0.6 : 1.0)
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if isDisabled {
            Capsule()
                .fill(Color.grayScale40)
        } else {
            Capsule()
                .fill(Color.white)
//                .shadow(color: Color(hex: "CECECE63"), radius: 4.8, x: 0, y: 0)
        }
    }
    
    @ViewBuilder
    private var borderView: some View {
        GeometryReader { geometry in
            if isDisabled {
                Capsule()
                    .stroke(lineWidth: 1.5)
                    .foregroundStyle(Color.grayScale40)
            } else {
                // Gradient border using ZStack technique
                ZStack {
                    // Outer gradient shape (full size)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "E8EBED"), Color(hex: "FFFFFF")],
                                startPoint: UnitPoint(x: 0.047, y: 0.5),
                                endPoint: UnitPoint(x: 1.83, y: 0.5)
                            )
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    
                    // Inner white shape to create 1.5px border effect
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geometry.size.width - 3, height: geometry.size.height - 3)
                }
            }
        }
    }
}

#Preview {
    ZStack {
//        Color.gray.opacity(0.1).ignoresSafeArea()
        VStack(spacing: 20) {
            SecondaryButton(title: "All Set!", action: {})
            SecondaryButton(title: "Maybe later", action: {})
            SecondaryButton(title: "Later", isLoading: true, action: {})
            SecondaryButton(title: "Disabled", isDisabled: true, action: {})
            SecondaryButton(title: "With Icon", icon: "share", iconWidth: 12, iconHeight: 12, action: {})
        }
        .padding()
    }
}
