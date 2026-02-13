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
    @StateObject private var onboarding: Onboarding
    @State private var webService: WebService
    @State private var memojiStore = MemojiStore()
    @State private var chatStore = ChatStore()
    @State private var foodNotesStore: FoodNotesStore

    init(restoredState: (canvas: CanvasRoute, sheet: BottomSheetRoute)? = nil) {
        // Create shared instances eagerly so FoodNotesStore is available
        // before any child view .task fires (fixes race condition where
        // HomeView.task could run while foodNotesStore was still nil).
        let ws = WebService()
        _webService = State(initialValue: ws)

        // Determine onboarding flow type from restored state
        let flowType: OnboardingFlowType
        if let state = restoredState, case .mainCanvas(let flow) = state.canvas {
            flowType = flow
        } else {
            flowType = .individual
        }
        let onb = Onboarding(onboardingFlowtype: flowType)
        _onboarding = StateObject(wrappedValue: onb)
        _foodNotesStore = State(initialValue: FoodNotesStore(webService: ws, onboardingStore: onb))

        if let state = restoredState {
            let coordinator = AppNavigationCoordinator(initialRoute: state.canvas)
            // Force the sheet immediately without animation for launch
            coordinator.navigateInBottomSheet(state.sheet)
            _coordinator = State(initialValue: coordinator)
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
            // BUT only if we're NOT on the family overview screen (letsMeetYourIngrediFam) or home screen
            // (where SettingsSheet might be shown)
            let isOnFamilyOverview = coordinator.currentCanvasRoute == .letsMeetYourIngrediFam
            let isOnHomeScreen = coordinator.currentCanvasRoute == .home
            let isFromMeetYourProfile: Bool = {
                if case .meetYourProfile = memojiStore.previousRouteForGenerateAvatar {
                    return true
                }
                return false
            }()
            let isMeetYourProfileRoute: Bool = {
                if case .meetYourProfile = coordinator.currentBottomSheetRoute {
                    return true
                }
                return false
            }()
            let shouldShowCustomBackground = (coordinator.currentBottomSheetRoute == .meetYourProfileIntro || 
               isMeetYourProfileRoute ||
               ((coordinator.currentBottomSheetRoute == .generateAvatar || 
                 coordinator.currentBottomSheetRoute == .yourCurrentAvatar ||
                 coordinator.currentBottomSheetRoute == .bringingYourAvatar ||
                 coordinator.currentBottomSheetRoute == .meetYourAvatar) && 
                (isFromMeetYourProfile || memojiStore.previousRouteForGenerateAvatar == .meetYourProfileIntro))) && !isOnFamilyOverview && !isOnHomeScreen
            
            if shouldShowCustomBackground {
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
        .environment(chatStore)
        .environment(foodNotesStore)
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
        // Global AI Bot sheet (post-login) - accessible from HomeView and other post-login screens
        .sheet(isPresented: $coordinator.isAIBotSheetPresented, onDismiss: {
            // Clear feedback context when sheet is dismissed (swipe down or skip)
            // This resets to product_scan context for next FAB tap
            coordinator.dismissAIBotSheet()
        }) {
            IngrediBotChatView(
                scanId: coordinator.aibotContextScanId,
                analysisId: coordinator.aibotContextAnalysisId,
                ingredientName: coordinator.aibotContextIngredientName,
                feedbackId: coordinator.aibotContextFeedbackId,
                contextKeyOverride: coordinator.aibotContextKeyOverride
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .environment(coordinator)
            .environment(appState)
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
            await withTaskGroup(of: Void.self) { group in
                // Family load runs concurrently — FamilyStore's isFetchInFlight
                // guard prevents duplicate calls if prefetch is already in-flight
                group.addTask { @MainActor in
                    await familyStore.loadCurrentFamily()
                }
                // Onboarding restoration runs concurrently
                group.addTask { @MainActor in
                    print("[OnboardingMeta] RootContainerView.task: attempting restore on launch")
                    await OnboardingPersistence.shared.restore(into: coordinator)

                    // These must run AFTER restore completes (coordinator state is now ready)
                    if let stepId = coordinator.currentOnboardingStepId {
                        onboarding.restoreState(forStepId: stepId)
                    } else if case .fineTuneYourExperience = coordinator.currentBottomSheetRoute {
                        onboarding.restoreState(forStepId: "lifeStyle")
                    } else if case .workingOnSummary = coordinator.currentBottomSheetRoute {
                        onboarding.restoreToLastStep()
                    }
                    onboarding.updateSectionCompletionStatus()
                }
                await group.waitForAll()
            }
        }
        // Whenever authentication completes (including first-time login or
        // upgrading a guest account), refresh the family from the backend so
        // the home screen immediately reflects the latest household state
        // without requiring an app restart.
        // Only navigate to home if we're not already on home canvas to avoid
        // disrupting navigation when Settings or other views are presented
        .onChange(of: authController.signInState) { _, newValue in
            if newValue == .signedIn {
                Task {
                    await familyStore.loadCurrentFamily()
                    if !authController.signedInAsGuest &&
                       OnboardingPersistence.shared.isLocallyCompleted &&
                       coordinator.currentCanvasRoute != .home {
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
                UnifiedCanvasView(
                    mode: .editing,
                    titleOverride: "Welcome to \(familyStore.family?.name ?? "your")'s family",
                    showBackButton: false
                )
            }
        case .mainCanvas(let flow):
            UnifiedCanvasView(mode: .onboarding(flow: flow))
        case .home:
            HomeView()
        case .summaryJustMe:
            NavigationStack {
                UnifiedCanvasView(mode: .editing, titleOverride: "Your Food Notes", showBackButton: false)
            }
        case .summaryAddFamily:
            NavigationStack {
                UnifiedCanvasView(mode: .editing, titleOverride: "Your IngrediFam Food Notes", showBackButton: false)
            }
        case .readyToScanFirstProduct:
            ReadyToScanCanvas()
        case .seeHowScanningWorks:
            ScanningHelpCanvas()
        case .whyWeNeedThesePermissions:
            PermissionsCanvas()
        }
    }

    @ViewBuilder
    private var editSheetOverlay: some View {
        @Bindable var coordinator = coordinator
        if coordinator.isEditSheetPresented, let stepId = coordinator.editingStepId {
            EditSectionBottomSheet(
                isPresented: $coordinator.isEditSheetPresented,
                stepId: stepId,
                currentSectionIndex: coordinator.currentEditingSectionIndex,
                initialMemberId: coordinator.editingMemberId
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
