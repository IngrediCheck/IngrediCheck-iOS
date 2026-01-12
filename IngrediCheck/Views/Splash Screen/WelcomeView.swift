//
//  FirstLaunchWelcomeView.swift
//  IngrediCheckPreview
//
//  Marketing carousel shown on first app launch
//

import SwiftUI

struct WelcomeView: View {
    @State private var isFillingComplete: Bool = false
    let onGetStarted: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                // FillingPipeLine at top
                FillingPipeLine(onComplete: {
                    isFillingComplete = true
                })
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                
                // Main heading
                Text("TIRED OF INGREDIENT LISTS THAT FEEL LIKE A PUZZLE?")
                    .font(ManropeFont.bold.size(24))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .padding(.top, 32)
                
                // Subtitle
                Text("IngrediCheck instantly highlights what's matched and unmatched.")
                    .font(ManropeFont.regular.size(14))
                    .foregroundStyle(.grayScale100)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 18)
                
                // Central illustration - image contains all visual elements
                Image("ph")
                    .resizable()
                    .scaledToFit()
//                    .frame(height: 610)
                    .padding(.bottom, 46)
                
                Spacer()
                
                // Get Started button
                if isFillingComplete {
                    Button {
                        onGetStarted()
                    } label: {
                        GreenCapsule(title: "Get Started")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        // Disabled - do nothing
                    } label: {
                        HStack(spacing: 8) {
                            Text("Get Started")
                                .font(NunitoFont.semiBold.size(16))
                                .foregroundStyle(.grayScale80)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Capsule()
                                .fill(.grayScale30)
                        )
                    }
                    .disabled(true)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isFillingComplete)
    }
}

struct FillingPipeLine: View {
    @State private var progress: CGFloat = 0
    @State private var shimmerOffset: CGFloat = -1
    let onComplete: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // 1️⃣ Empty pipe (track)
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(hex:"#EEEEEE"), lineWidth: 1)

                // 2️⃣ Filling layer
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex:"#D3D3D3"))
                    .frame(width: geo.size.width)
                    .scaleEffect(x: progress, y: 1, anchor: .leading)
            }
        }
        .frame(height: 4)
        .onAppear {
            withAnimation(
                .linear(duration: 5)
            ) {
                progress = 1
            }
            // Trigger completion after animation duration
            Task {
                try? await Task.sleep(nanoseconds: UInt64(5 * 1_000_000_000))
                await MainActor.run {
                    onComplete()
                }
            }
        }
    }
}

#Preview {
    WelcomeView(onGetStarted: {})
}
