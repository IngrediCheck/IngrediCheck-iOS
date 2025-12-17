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

    init(initialRoute: CanvasRoute = .heyThere) {
        if let snapshot = OnboardingResumeStore.load() {
            let restored = AppNavigationCoordinator.restoreFromSnapshot(snapshot)
            let coordinator = AppNavigationCoordinator(initialRoute: restored.canvas)
            coordinator.navigateInBottomSheet(restored.sheet)
            _coordinator = State(initialValue: coordinator)
        } else {
            _coordinator = State(initialValue: AppNavigationCoordinator(initialRoute: initialRoute))
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
            
            // Always attempt to restore onboarding position on launch.
            // This will:
            // - Prefer Supabase metadata if a session exists
            // - Otherwise use the locally cached metadata
            print("[OnboardingMeta] RootContainerView.task: attempting restoreOnboardingPosition on launch")
            authController.restoreOnboardingPosition(into: coordinator)
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
