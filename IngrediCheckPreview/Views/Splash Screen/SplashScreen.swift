//
//  SplashScreen.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/11/25.
//

import SwiftUI

struct SplashScreen: View {
    private let slides: [SplashSlide] = [
        .init(
            title: "Know What's Inside, Instantly",
            subtitle: "Scan any product and get clear, simple answers, no more confusing labels."
        ),
        .init(
            title: "Made for Your IngrediFam",
            subtitle: "Allergies, diets, or family needs, your scans adapt to everyone you care for."
        ),
        .init(
            title: "Shop & Eat with Confidence",
            subtitle: "Get healthier, safer alternatives without second-guessing."
        )
    ]
    
    @State private var currentIndex: Int = 0
    
    var body: some View {
        NavigationStack {
            VStack {
                
                Spacer()
                Spacer()
                
                VStack {
                    Text(slide.title)
                        .font(NunitoFont.bold.size(22))
                        .foregroundStyle(.grayScale150)
                    Text(slide.subtitle)
                        .font(ManropeFont.medium.size(14))
                        .foregroundStyle(.grayScale100)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                HStack {
                    
                    HStack {
                        ForEach(slides.indices, id: \.self) { index in
                            Capsule()
                                .frame(width: currentIndex == index ? 24 : 5.5, height: 5.5)
                                .foregroundStyle(
                                    currentIndex == index
                                    ? LinearGradient(colors: [Color(hex: "8DB90D"), Color(hex: "6B8E06")], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [.primary800.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                                )
                        }
                    }
                    
                    Spacer()
                    
                    if isLastSlide {
                        NavigationLink {
                            RootContainerView()
                        } label: {
                            GreenCapsule(title: "Get Started")
                                .frame(width: 159)
                        }
                    } else {
                        Button {
                            withAnimation(.smooth) {
                                currentIndex = min(currentIndex + 1, slides.count - 1)
                            }
                        } label: {
                            GreenCircle()
                        }
                    }
                }
                .animation(.smooth, value: currentIndex)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var slide: SplashSlide {
        guard slides.indices.contains(currentIndex) else {
            return slides.first ?? .init(title: "", subtitle: "")
        }
        return slides[currentIndex]
    }
    
    private var isLastSlide: Bool {
        currentIndex >= slides.count - 1
    }
}

#Preview {
    SplashScreen()
}

private struct SplashSlide: Hashable {
    let title: String
    let subtitle: String
}
