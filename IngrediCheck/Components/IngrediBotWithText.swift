//
//  IngrediBotWithText.swift
//  IngrediCheckPreview
//
//  Created on 13/11/25.
//

import SwiftUI

struct IngrediBotWithText: View {
    let text: String
    var showBackgroundImage: Bool = true
    var viewDidAppear: (() -> Void)? = nil
    var delay: TimeInterval = 2.0
    @State private var backgroundOpacity: Double = 0.3
    @State private var shimmerOffset: CGFloat = -200
    @State private var botOffsetX: CGFloat = 0
    @State private var botOffsetY: CGFloat = 0
    
    var body: some View {
        VStack( ) {
            ZStack{
                if showBackgroundImage {
                    Image("backgroundimage")
                        .resizable()
                        .scaledToFit()
                        .clipped()
                        .frame(width: 335, height: 199)
                        .opacity(backgroundOpacity)
                }
                Image("ingrediBot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 147, height: 147)
                    .clipped()
                    .offset(x: botOffsetX, y: botOffsetY)
                    .overlay(
                        // Shimmer effect
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.4),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 70)
                        .offset(x: shimmerOffset)
                        .blendMode(.overlay)
                    )
            }
            
            VStack(spacing: 24) {
                Text(text)
                    .font(NunitoFont.bold.size(20))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                    .offset(x : 0, y : -30)
            }
            
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
        .onAppear() {
            // Start the fade animation
            if showBackgroundImage {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    backgroundOpacity = 1.0
                }
            }
            
            // Start the shimmer animation - continuously loop from left to right
            shimmerOffset = -200
            withAnimation(.linear(duration: 3.6).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
            
            // Start the robot movement animation - smooth floating movement
            // Horizontal movement (left-right)
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                botOffsetX = 8
            }
            
            // Vertical movement (up-down) with slight delay for more natural movement
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    botOffsetY = -6
                }
            }
            
            if let viewDidAppear = viewDidAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    viewDidAppear()
                }
            }
        }
        .onDisappear {
            // Reset positions when view disappears
            botOffsetX = 0
            botOffsetY = 0
            shimmerOffset = -200
            backgroundOpacity = 0.3
        }
    }
}

#Preview {
    IngrediBotWithText(text: "Bringing your avatar to life... it's going to be awesome!")
}

