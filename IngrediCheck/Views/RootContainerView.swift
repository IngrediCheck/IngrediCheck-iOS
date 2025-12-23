//
//  RootContainerView.swift
//  IngrediCheckPreview
//
//  Created on 13/11/25.
//

import SwiftUI

struct RootContainerView: View {
    @State private var coordinator: AppNavigationCoordinator
    @StateObject private var onboarding = Onboarding(onboardingFlowtype: .individual)
    @State private var webService = WebService()
    @State private var memojiStore = MemojiStore()

    init(restoredState: (canvas: CanvasRoute, sheet: BottomSheetRoute)? = nil) {
        if let state = restoredState {
            let coordinator = AppNavigationCoordinator(initialRoute: state.canvas)
            // Force the sheet immediately without animation for launch
            coordinator.navigateInBottomSheet(state.sheet)
            _coordinator = State(initialValue: coordinator)
            
            // Also sync the Onboarding view model if we are in main canvas
            if case .mainCanvas(let flow) = state.canvas {
                 _onboarding = StateObject(wrappedValue: Onboarding(onboardingFlowtype: flow))
            }
             // Should we restore step ID? Onboarding model needs it.
             // We can do that in .task since Onboarding is a StateObject and accessing it int init is tricky if we want to call methods.
             // But initializing with flow type is good.
        } else {
            _coordinator = State(initialValue: AppNavigationCoordinator(initialRoute: .heyThere))
        }
    }

    // --- HEAD BRANCH (keep these)
    @State private var appState = AppState()
    @State private var userPreferences = UserPreferences()

    // --- DEVELOP BRANCH (keep these)
    @Environment(FamilyStore.self) private var familyStore
    @Environment(AuthController.self) private var authController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var coordinator = coordinator

        ZStack(alignment: .bottom) {
            canvasContent(for: coordinator.currentCanvasRoute)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Dim background when certain sheets are presented (e.g., Invite)
            Group {
                switch coordinator.currentBottomSheetRoute {
                case .wouldYouLikeToInvite(_, _):
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                default:
                    EmptyView()
                }
            }

            PersistentBottomSheet()
        }
        .environment(coordinator)
        .environmentObject(onboarding)
        .environment(webService)
        .environment(appState)
        .environment(userPreferences)
        .environment(authController)
        .environment(memojiStore)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AppDidReset"))) { _ in
            coordinator = AppNavigationCoordinator(initialRoute: .heyThere)
            onboarding.reset(flowType: .individual)
            familyStore.resetLocalState()
            dismiss()
        }
        .onAppear {
            // Set up callback to sync onboarding state to Supabase whenever navigation changes
            coordinator.onNavigationChange = {
                print("[OnboardingMeta] onNavigationChange fired with canvasRoute=\(coordinator.currentCanvasRoute), bottomSheetRoute=\(coordinator.currentBottomSheetRoute)")
                await authController.syncRemoteOnboardingMetadata(from: coordinator)
            }
        }
        .task {
            // Load family state when the container becomes active.
            await familyStore.loadCurrentFamily()
// <<<<<<< HEAD
//             // If Supabase already has a restored non-guest session at launch,
//             // route directly to Home instead of replaying onboarding.
//             if authController.session != nil && !authController.signedInAsGuest {
//                 await MainActor.run {
//                     coordinator.showCanvas(.home)
//                 }
// =======
            
            // Always attempt to restore onboarding position on launch from Supabase metadata.
            // Guest login should happen at whosThisFor, so session should exist by then.
            print("[OnboardingMeta] RootContainerView.task: attempting restoreOnboardingPosition on launch")
            authController.restoreOnboardingPosition(into: coordinator)
            
            // Sync Onboarding view model to match the restored coordinator state
            if let stepId = coordinator.currentOnboardingStepId {
                onboarding.restoreState(forStepId: stepId)
// >>>>>>> Develop
            }
        }
        // Whenever authentication completes (including first-time login or
        // upgrading a guest account), refresh the family from the backend so
        // the home screen immediately reflects the latest household state
        // without requiring an app restart.
        .onChange(of: authController.signInState) { _, newValue in
            if newValue == .signedIn {
                Task {
                    await familyStore.loadCurrentFamily()
                    if !authController.signedInAsGuest {
                        await MainActor.run {
                            coordinator.showCanvas(.home)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func canvasContent(for route: CanvasRoute) -> some View {
        switch route {
        case .heyThere:
            HeyThereScreen()
        case .blankScreen:
            BlankScreen()
        case .letsGetStarted:
            LetsGetStartedView()
        case .letsMeetYourIngrediFam:
            LetsMeetYourIngrediFamView()
        case .dietaryPreferencesAndRestrictions(let isFamilyFlow):
            DietaryPreferencesAndRestrictions(isFamilyFlow: isFamilyFlow)
        case .welcomeToYourFamily:
            WelcomeToYourFamilyView()
        case .mainCanvas(let flow):
            MainCanvasView(flow: flow)
        case .home:
            HomeView()
        }
    }
}
