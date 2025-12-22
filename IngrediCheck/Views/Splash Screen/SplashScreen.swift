//
//  SplashScreen.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/11/25.
//

import SwiftUI

struct SplashScreen: View {
    @State private var isFirstLaunch: Bool = true
    @State private var isCheckingLaunchState: Bool = true
    @State private var isFillingComplete: Bool = false
    @State private var shouldNavigateToHome: Bool = false
    @Environment(AuthController.self) private var authController
    @Environment(FamilyStore.self) private var familyStore
    
    var body: some View {
        Group {
            if isCheckingLaunchState {
                Image("SplashScreen")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else if shouldNavigateToHome {
                // In preview flow, if there's already a Supabase session
                // (including anonymous/guest), skip the marketing carousel
                // and go straight into the main container.
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
                    VStack(spacing: 0) {
                        FillingPipeLine(onComplete: {
                            isFillingComplete = true
                        })
                      
                     
                        
                        Image("onbording-emptyimg1s")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 610)
                            .padding(.top, 18)
                            .padding(.bottom , 46)
                        
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
            
            // Calculate navigation decision once based on initial state
            if !isFirstLaunch && authController.session != nil {
                shouldNavigateToHome = true
            }

            isCheckingLaunchState = false
            // Do NOT auto-sign-in here; login should only happen when
            // the user explicitly chooses a provider or taps "Sign-in later".
        }
        // If a session restores slightly after first frame, reactively
        // navigate to Home for returning users (non-first launch).
        .onChange(of: authController.signInState) { _, newValue in
            if !isFirstLaunch && newValue == .signedIn {
                shouldNavigateToHome = true
            }
        }
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
                //change duration  acording to GIF
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
    SplashScreen()
        .environment(AuthController())
        .environment(FamilyStore())
}
