//
//  CaptureYourProductSheet.swift
//  IngrediCheck
//
//  Created on [Date].
//

import SwiftUI

struct CaptureYourProductSheet: View {
    let onDismiss: () -> Void

    @State private var currentSlide = 0
    @State private var timerTask: Task<Void, Never>?

    private let slideCount = 5
    private let slideDuration: TimeInterval = 3.0

    private struct SlideData {
        let imageName: String
        let isIntro: Bool
        let subtitlePrefix: String
        let subtitleKeyword: String
        let subtitleSuffix: String
        let description: String
    }

    private let slides: [SlideData] = [
        SlideData(
            imageName: "botwithgrid",
            isIntro: true,
            subtitlePrefix: "", subtitleKeyword: "", subtitleSuffix: "",
            description: "We'll guide you through a few angles so our AI can identify the product and its ingredients accurately."
        ),
        SlideData(
            imageName: "front-product",
            isIntro: false,
            subtitlePrefix: "First, take a photo of the ",
            subtitleKeyword: "front",
            subtitleSuffix: " of the product.",
            description: ""
        ),
        SlideData(
            imageName: "back-product",
            isIntro: false,
            subtitlePrefix: "Next, capture the ",
            subtitleKeyword: "back side",
            subtitleSuffix: ".",
            description: ""
        ),
        SlideData(
            imageName: "nutrition-product",
            isIntro: false,
            subtitlePrefix: "Then, take photo of ",
            subtitleKeyword: "Nutrition facts",
            subtitleSuffix: ".",
            description: ""
        ),
        SlideData(
            imageName: "ingredients-product",
            isIntro: false,
            subtitlePrefix: "Finally, take a clear photo of the ",
            subtitleKeyword: "Ingredient list",
            subtitleSuffix: ".",
            description: ""
        ),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {

                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image("xmark")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(Color(.lightGray))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 20)
                .padding(.trailing, 20)

                VStack(spacing: 12) {
                    // Title
                    Text("Guide to capture photos")
                        .font(NunitoFont.bold.size(24))
                        .foregroundColor(.grayScale150)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    // Subtitle (slides 1-4 only)
                    if !slides[currentSlide].isIntro {
                        subtitleView(for: slides[currentSlide])
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 24)
                            .padding(.bottom)
                    }
                }

                // Image area
                slideImageView()

                // Description (slide 0 only)
                if slides[currentSlide].isIntro {
                    Text(slides[currentSlide].description)
                        .font(NunitoFont.medium.size(14))
                        .foregroundColor(Color(.grayScale140))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 45)
                }

                // Footer
                Text("Capture the front, back, barcode, and ingredient details of the product.")
                    .font(NunitoFont.regular.size(10))
                    .foregroundColor(Color(.grayScale110))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 431)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .shadow(color: Color(hex: "#D9D9D9").opacity(0.42), radius: 27.5)
        .padding(.bottom, 0)
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            timerTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: UInt64(slideDuration * 1_000_000_000))
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentSlide = (currentSlide + 1) % slideCount
                    }
                }
            }
        }
        .onDisappear {
            timerTask?.cancel()
        }
    }

    @ViewBuilder
    private func slideImageView() -> some View {
        let slide = slides[currentSlide]

        if slide.isIntro {
            ZStack {
                Image("backGrids")
                    .resizable()
                    .scaledToFit()
                Image("botwithgrid")
                    .resizable()
                    .scaledToFit()
            }
            .id(currentSlide)
            .transition(.opacity)
        } else {
            Image(slide.imageName)
                .resizable()
                .scaledToFit()
                .id(currentSlide)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
        }
    }

    private func subtitleView(for slide: SlideData) -> Text {
        Text(slide.subtitlePrefix)
            .font(NunitoFont.medium.size(14))
            .foregroundColor(Color(.grayScale140))
        +
        Text(slide.subtitleKeyword)
            .font(NunitoFont.extraBold.size(14))
            .foregroundColor(Color(hex: "91B640"))
        +
        Text(slide.subtitleSuffix)
            .font(NunitoFont.medium.size(14))
            .foregroundColor(Color(.grayScale140))
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.35)
            .ignoresSafeArea()

        VStack {
            Spacer()

            CaptureYourProductSheet(onDismiss: {})
        }
    }
    .ignoresSafeArea(edges: .bottom)
}
