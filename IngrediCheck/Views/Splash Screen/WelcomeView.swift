//
//  FirstLaunchWelcomeView.swift
//  IngrediCheckPreview
//
//  Marketing carousel shown on first app launch
//

import SwiftUI
import RiveRuntime

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
                .zIndex(1)
                
                // Central illustration - Rive animation
                RiveViewModel(fileName: "ingridecheck")
                    .view()
                    .scaleEffect(1.3)
//                    .aspectRatio(contentMode: .fill)
//                    .padding(.bottom, 46)
                
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
                    .zIndex(2)
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
                    .zIndex(2)
                }
                
                LegalDisclaimerView()

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
                .linear(duration: 18)
            ) {
                progress = 1
            }
            // Trigger completion after animation duration
            Task {
                try? await Task.sleep(nanoseconds: UInt64(8 * 1_000_000_000))
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
