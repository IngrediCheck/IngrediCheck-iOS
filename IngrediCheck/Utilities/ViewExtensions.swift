//
//  ViewExtensions.swift
//  IngrediCheck
//
//  Created for reusable view modifiers
//

import SwiftUI

extension View {
    /// Adds a bottom gradient overlay and TabBar to a view
    /// - Parameters:
    ///   - gradientColors: Colors for the bottom gradient (default: transparent to #FCFCFE)
    ///   - gradientHeight: Height of the gradient overlay (default: 132)
    ///   - bar: The TabBar view to display at the bottom
    /// - Returns: A view with bottom gradient and TabBar overlay
    func withBottomTabBar<Bar: View>(
        gradientColors: [Color] = [
            Color.white.opacity(0),
            Color(hex: "#FCFCFE")
        ],
        gradientHeight: CGFloat = 132,
        @ViewBuilder bar: () -> Bar
    ) -> some View {
        self
            .overlay(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: gradientHeight)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false),
                alignment: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .overlay(
                bar(),
                alignment: .bottom
            )
    }
}

/// View modifier for conditionally applying bottom tab bar with gradient
struct ConditionalBottomTabBar<Bar: View>: ViewModifier {
    let isEnabled: Bool
    let gradientColors: [Color]
    let gradientHeight: CGFloat
    @ViewBuilder let bar: () -> Bar
    
    init(
        isEnabled: Bool,
        gradientColors: [Color] = [
            Color.white.opacity(0),
            Color(hex: "#FCFCFE")
        ],
        gradientHeight: CGFloat = 132,
        @ViewBuilder bar: @escaping () -> Bar
    ) {
        self.isEnabled = isEnabled
        self.gradientColors = gradientColors
        self.gradientHeight = gradientHeight
        self.bar = bar
    }
    
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .overlay(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: gradientHeight)
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false),
                    alignment: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
                .overlay(
                    bar(),
                    alignment: .bottom
                )
        } else {
            content
        }
    }
}
