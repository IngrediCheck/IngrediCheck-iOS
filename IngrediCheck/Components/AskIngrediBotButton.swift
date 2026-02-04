//
//  AskIngrediBotButton.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 08/10/25.
//

import SwiftUI

struct AskIngrediBotButton: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    var action: (() -> Void)?

    @State private var textShimmerPhase: CGFloat = 0
    @State private var shimmerTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: -16) {
            Image("ingrediBot")
                .frame(width: 76, height: 76)
                .offset(x: -4)
                .zIndex(1)


            Button {
                if let action {
                    action()
                } else {
                    coordinator.presentChatBot(startAtConversation: true)
                }
            } label: {
                HStack(spacing: 4) {
                    Image("ai-stars")
                        .resizable()
                        .frame(width: 18, height: 18)

                    Microcopy.text(Microcopy.Key.Chat.ctaAskIngrediBot)
                        .font(NunitoFont.semiBold.size(12))
                        .foregroundStyle(.grayScale10)
                        .overlay(
                            GeometryReader { geo in
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0),
                                        .white.opacity(0.6),
                                        .white.opacity(0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: geo.size.width * 0.6)
                                .offset(x: -geo.size.width * 0.3 + geo.size.width * 1.3 * textShimmerPhase)
                                .mask(
                                    Microcopy.text(Microcopy.Key.Chat.ctaAskIngrediBot)
                                        .font(NunitoFont.semiBold.size(12))
                                )
                            }
                            .clipped()
                        )
                }
            }
            .onAppear {
                shimmerTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                    Task { @MainActor in
                        textShimmerPhase = 0
                        withAnimation(.easeInOut(duration: 1.0)) {
                            textShimmerPhase = 1
                        }
                    }
                }
            }
            .onDisappear {
                shimmerTimer?.invalidate()
                shimmerTimer = nil
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 33)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color(hex: "#6F9600"), location: 0.2),   // start at 0%
                                    .init(color: Color(hex: "#90C02B"), location: 0.5),   // up to 50%
                                    .init(color: Color(hex: "#789D0E"), location: 1.1)    // up to 90%
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .shadow(
                                .inner(color: .primary400.opacity(0.85), radius: 2, x: 0, y: 3)
                            )
                            .shadow(
                                .drop(color: Color(hex: "C5C5C5"), radius: 8.8, x: 0, y: 2)
                            )
                        )
                    
                    Image("ingredi-bot-button-background")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 146, height: 48)
                        .opacity(0.2)
                        .clipShape(RoundedRectangle(cornerRadius: 33))
                }
            )
        }
    }
}

#Preview {
    AskIngrediBotButton()
        .environment(AppNavigationCoordinator())
}
