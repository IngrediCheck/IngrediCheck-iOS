//
//  RootContainerView.swift
//  IngrediCheckPreview
//
//  Created on 13/11/25.
//

import SwiftUI
import Observation

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
        @Bindable var appState = appState
        @Bindable var toastManager = ToastManager.shared

        ZStack(alignment: .bottom) {
            // Show custom background when meetYourProfileIntro or meetYourProfile bottom sheet is active
            if coordinator.currentBottomSheetRoute == .meetYourProfileIntro || 
               coordinator.currentBottomSheetRoute == .meetYourProfile ||
               ((coordinator.currentBottomSheetRoute == .generateAvatar || 
                 coordinator.currentBottomSheetRoute == .yourCurrentAvatar ||
                 coordinator.currentBottomSheetRoute == .bringingYourAvatar ||
                 coordinator.currentBottomSheetRoute == .meetYourAvatar) && 
                (memojiStore.previousRouteForGenerateAvatar == .meetYourProfile || memojiStore.previousRouteForGenerateAvatar == .meetYourProfileIntro)) {
                VStack {
                    Text("Meet your profile")
                        .font(ManropeFont.bold.size(16))
                        .padding(.top, 32)
                        .padding(.bottom, 4)
                    Text("This helps us tailor food checks and tips just for you.")
                        .font(ManropeFont.regular.size(13))
                        .foregroundColor(Color(hex: "#BDBDBD"))
                        .lineLimit(2)
                        .frame(width: 247)
                        .multilineTextAlignment(.center)
                    
                    Image("addfamilyimg")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 369)
                        .frame(maxWidth: .infinity)
                        .offset(y: -50)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                canvasContent(for: coordinator.currentCanvasRoute)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

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
            
            // Toast Overlay
            if let toastData = toastManager.toast, toastManager.isPresented {
                VStack {
                    ToastView(data: toastData) {
                        toastManager.dismiss()
                    }
                    Spacer()
                }
                .padding(.top, 60) // Adjust based on safe area or design
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(200) // Ensure on top of everything including edit sheet
            }
            
            // Secondary edit sheet overlay on top of everything (z-index 100)
            editSheetOverlay
        }
        .environment(coordinator)
        .environmentObject(onboarding)
        .environment(webService)
        .environment(appState)
        .environment(userPreferences)
        .environment(authController)
        .environment(memojiStore)
        // Allow presenting SettingsSheet from anywhere in this container
        .sheet(item: $appState.activeSheet) { sheet in
            switch sheet {
            case .settings:
                SettingsSheet()
                    .environment(userPreferences)
                    .environment(memojiStore)
                    .environment(coordinator)
            case .scan:
                // Not used here; keep empty or route to a scan view if needed later
                EmptyView()
            }
        }
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
                await OnboardingPersistence.shared.sync(from: coordinator)
            }
        }
        .task {
            // Load family state when the container becomes active.
            await familyStore.loadCurrentFamily()
            // Always attempt to restore onboarding position on launch from Supabase metadata.
            // Guest login should happen at whosThisFor, so session should exist by then.
            print("[OnboardingMeta] RootContainerView.task: attempting restoreOnboardingPosition on launch")
            authController.restoreOnboardingPosition(into: coordinator)
            
            // Sync Onboarding view model to match the restored coordinator state
            if let stepId = coordinator.currentOnboardingStepId {
                onboarding.restoreState(forStepId: stepId)
            } else if case .fineTuneYourExperience = coordinator.currentBottomSheetRoute {
                onboarding.restoreState(forStepId: "lifeStyle")
            } else if case .workingOnSummary = coordinator.currentBottomSheetRoute {
                onboarding.restoreToLastStep()
            }
            
            // Ensure section completion status is accurate based on loaded preferences
            onboarding.updateSectionCompletionStatus()
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
            NavigationStack {
                EditableCanvasView(
                    titleOverride: "Welcome to \(familyStore.family?.name ?? "your")'s family",
                    showBackButton: false
                )
            }
        case .mainCanvas(let flow):
            MainCanvasView(flow: flow)
        case .home:
            HomeView()
        case .summaryJustMe:
            NavigationStack {
                EditableCanvasView(titleOverride: "Your Food Notes", showBackButton: false)
            }
        case .summaryAddFamily:
            NavigationStack {
                EditableCanvasView(titleOverride: "Your IngrediFam Food Notes", showBackButton: false)
            }
        }
    }

    @ViewBuilder
    private var editSheetOverlay: some View {
        @Bindable var coordinator = coordinator
        if coordinator.isEditSheetPresented, let stepId = coordinator.editingStepId {
            EditSectionBottomSheet(
                isPresented: $coordinator.isEditSheetPresented,
                stepId: stepId,
                currentSectionIndex: coordinator.currentEditingSectionIndex
            )
            .transition(AnyTransition.asymmetric(
                insertion: AnyTransition.move(edge: Edge.bottom).combined(with: AnyTransition.opacity),
                removal: AnyTransition.move(edge: Edge.bottom).combined(with: AnyTransition.opacity)
            ))
            .zIndex(100)
            .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity, alignment: Alignment.bottom)
            .ignoresSafeArea()
        }
    }
}
