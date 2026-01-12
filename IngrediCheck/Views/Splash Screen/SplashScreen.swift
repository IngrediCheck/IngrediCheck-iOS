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
    @State private var shouldNavigateToHome: Bool = false
    @State private var shouldNavigateToOnboarding: Bool = false
    @State private var shouldNavigateFromWelcome: Bool = false
    @State private var restoredState: (canvas: CanvasRoute, sheet: BottomSheetRoute)?
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
                    RootContainerView(restoredState: (canvas: .home, sheet: .homeDefault))
                        .environment(authController)
                        .environment(familyStore)
                }
            } else if shouldNavigateFromWelcome {
                // User tapped "Get Started" - navigate directly without showing splash again
                RootContainerView(restoredState: restoredState)
                    .environment(authController)
                    .environment(familyStore)
            } else if shouldNavigateToOnboarding {
                // If there's a session but onboarding isn't complete,
                // go to RootContainerView which will restore from metadata
                Splash {
                    Image("SplashScreen")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                } content: {
                    RootContainerView(restoredState: restoredState)
                        .environment(authController)
                        .environment(familyStore)
                }
            } else {
                WelcomeView(onGetStarted: {
                    restoredState = nil
                    shouldNavigateFromWelcome = true
                })
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
                // We call signOut unconditionally to handle race conditions where
                // authController.session might still be nil but GoTrue is restoring.
                print("[SplashScreen] First launch detected. Ensuring clean slate.")
                await authController.signOut()
            } else {
                isFirstLaunch = false
            }
            
            // Wait a bit for session to be fully restored and metadata to be available
            // The session might be restored from keychain but userMetadata might need a moment
            if !isFirstLaunch {
                // Check if session exists (or wait briefly if we suspect it should)
                // Actually authController.session might be nil initially but update shortly.
                // We'll give it a tiny grace period if it's nil? 
                // Checks on kill/launch typically have session ready from keychain immediately if using GoTrue synchronously or fast async.
                
                if authController.session != nil {
                     print("[SplashScreen] Session exists, checking metadata...")
                    // Session exists
                } else {
                     // Maybe wait 0.1s just in case session is being restored async?
                     try? await Task.sleep(nanoseconds: 100_000_000)
                }
                
                if authController.session != nil {
                    // Check metadata
                    let metadata = await OnboardingPersistence.shared.fetchRemoteMetadata()
                    print("[SplashScreen] Metadata check result: \(metadata != nil ? "found" : "not found")")
                    
                    if let metadata = metadata {
                        if metadata.stage == .completed {
                            shouldNavigateToHome = true
                            print("[SplashScreen] ✅ Onboarding complete, navigating to home")
                        } else {
                            // Restore state specifically
                            restoredState = AppNavigationCoordinator.restoreState(from: metadata)
                            shouldNavigateToOnboarding = true
                            print("[SplashScreen] ⚠️ Onboarding not complete, restoring to \(restoredState?.canvas ?? .heyThere)")
                        }
                    } else {
                        // Session exists but no metadata? Navigate to onboarding start I guess.
                        shouldNavigateToOnboarding = true
                        print("[SplashScreen] ⚠️ No metadata found, navigating to Onboarding Default")
                    }
                }
            }

            isCheckingLaunchState = false
            // Do NOT auto-sign-in here; login should only happen when
            // the user explicitly chooses a provider or taps "Sign-in later".
        }
        // If a session restores slightly after first frame, reactively
        // navigate to Home for returning users (non-first launch).
//        .onChange(of: authController.signInState) { _, newValue in
//            if !isFirstLaunch && newValue == .signedIn {
//                shouldNavigateToHome = true
//            }
//        }
    }
}

#Preview {
    SplashScreen()
        .environment(AuthController())
        .environment(FamilyStore())
}
