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
    @State private var isFirstLaunch: Bool = true
    @Environment(AuthController.self) private var authController
    @Environment(FamilyStore.self) private var familyStore
    
    var body: some View {
        // In preview flow, if there's already a non-guest Supabase session
        // (e.g., user previously logged in with Google/Apple), skip the
        // marketing carousel and go straight into the main container.
        // However, on a true first launch after install we always want to
        // start from the first screen, even if a stale session exists in
        // keychain. That first-launch detection is handled in the .task
        // below and reflected via isFirstLaunch.
        if !isFirstLaunch, authController.session != nil, !authController.signedInAsGuest {
            // For returning logged-in users in preview flow, show a short
            // branded splash image before transitioning directly to Home.
            Splash {
                Image("SplashScreen")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } content: {
                RootContainerView(initialRoute: .home)
                    .environment(authController)
                    .environment(familyStore)
            }
        } else {
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
                                    .environment(authController)
                                    .environment(familyStore)
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
            .task {
                let firstLaunchKey = "hasLaunchedOncePreviewFlow"
                let hasLaunchedBefore = UserDefaults.standard.bool(forKey: firstLaunchKey)

                if !hasLaunchedBefore {
                    // Mark that we've now launched at least once. For this
                    // initial launch we force onboarding by treating it as
                    // first launch even if a stale session exists in keychain.
                    UserDefaults.standard.set(true, forKey: firstLaunchKey)
                    isFirstLaunch = true

                    // If we somehow already have a Supabase session on first
                    // launch (e.g., carried over via keychain from a previous
                    // install), clear it so the user is not auto-logged in
                    // before they choose Google/Apple or "Sign-in later".
                    if authController.session != nil {
                        await authController.signOut()
                    }
                } else {
                    isFirstLaunch = false
                }
                // Do NOT auto-sign-in here; login should only happen when
                // the user explicitly chooses a provider or taps "Sign-in later".
            }
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
