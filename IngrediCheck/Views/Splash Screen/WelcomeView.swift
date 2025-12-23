//
//  FirstLaunchWelcomeView.swift
//  IngrediCheckPreview
//
//  Marketing carousel shown on first app launch
//

import SwiftUI

struct WelcomeView: View {
    @State private var isFillingComplete: Bool = false
    @Environment(AuthController.self) private var authController
    @Environment(FamilyStore.self) private var familyStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FillingPipeLine(onComplete: {
                    isFillingComplete = true
                })

                Image("onbording-emptyimg1s")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 610)
                    .padding(.top, 18)
                    .padding(.bottom, 46)

                if isFillingComplete {
                    HStack {
                        Spacer()
                        NavigationLink {
                            RootContainerView()
                                .environment(authController)
                                .environment(familyStore)
                        } label: {
                            GreenCapsule(title: "Get Started")
                        }
                    }
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
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isFillingComplete)
            .padding(.horizontal, 20)
            .navigationBarHidden(true)
        }
        .ignoresSafeArea(edges: .top)
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
    WelcomeView()
        .environment(AuthController())
        .environment(FamilyStore())
}
