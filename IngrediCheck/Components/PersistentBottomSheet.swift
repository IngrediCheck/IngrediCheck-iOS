//
//  PersistentBottomSheet.swift
//  IngrediCheckPreview
//
//  Created on 13/11/25.
//

import SwiftUI
import UIKit

struct PersistentBottomSheet: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(AuthController.self) private var authController
    @Environment(FamilyStore.self) private var familyStore
    @Environment(MemojiStore.self) private var memojiStore
    @Environment(WebService.self) private var webService
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var store: Onboarding
    @State private var keyboardHeight: CGFloat = 0
    @State private var isExpandedMinimal: Bool = false
    @State private var generationTask: Task<Void, Never>?
    @State private var tutorialData: TutorialData? 
    @State private var isAnimatingHand: Bool = false
    @State private var dragOffsetY: CGFloat = 0
    @State private var isGeneratingInviteCode: Bool = false

    // MARK: - CONSTANTS

    private let appStoreURL = "https://apps.apple.com/us/app/ingredicheck-grocery-scanner/id6477521615"
    
    var body: some View {
        @Bindable var coordinator = coordinator
        @Bindable var memojiStore = memojiStore

        let canTapOutsideToDismiss: Bool = {
            guard case .home = coordinator.currentCanvasRoute else { return false }

            switch coordinator.currentBottomSheetRoute {
            case .homeDefault:
                return false
            case .yourCurrentAvatar, .setUpAvatarFor, .generateAvatar, .bringingYourAvatar, .meetYourAvatar, .meetYourProfile, .meetYourProfileIntro:
                return true
            default:
                return false
            }
        }()
        
        ZStack(alignment: .bottom) {
            if canTapOutsideToDismiss {
                Color.black
                    .opacity(0.0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        coordinator.navigateInBottomSheet(.homeDefault)
                    }
            }

            VStack {
                Spacer()
                
                bottomSheetContainer()
            }
        }
        .background(
            .clear
        )
        .padding(.bottom, keyboardHeight)
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: coordinator.currentBottomSheetRoute) { oldValue, newValue in
            // Cancel generation task only when leaving avatar-related routes
            // Don't cancel when transitioning between avatar routes (generateAvatar -> bringingYourAvatar -> meetYourAvatar)
            let avatarRoutes: Set<BottomSheetRoute> = [.generateAvatar, .bringingYourAvatar, .meetYourAvatar, .yourCurrentAvatar, .setUpAvatarFor]
            let wasInAvatarFlow = avatarRoutes.contains(oldValue)
            let isInAvatarFlow = avatarRoutes.contains(newValue)
            
            // Only cancel if we're leaving the avatar flow entirely
            if wasInAvatarFlow && !isInAvatarFlow {
                print("[PersistentBottomSheet] Leaving avatar flow, cancelling generation task")
                generationTask?.cancel()
                generationTask = nil
            }

            // Animate sheet presentation (swipe-up feel) for avatar sheets opened from Home/Settings
            if (newValue == .yourCurrentAvatar || newValue == .setUpAvatarFor),
               !(oldValue == .yourCurrentAvatar || oldValue == .setUpAvatarFor),
               case .home = coordinator.currentCanvasRoute {
                dragOffsetY = 700
                withAnimation(.easeOut(duration: 0.28)) {
                    dragOffsetY = 0
                }
            } else {
                dragOffsetY = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            guard let userInfo = notification.userInfo,
                  let frameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            else { return }
            
            let screenHeight = UIScreen.main.bounds.height
            let keyboardVisibleHeight = max(0, screenHeight - frameValue.origin.y)
            
            withAnimation(.easeInOut(duration: 0.25)) {
                keyboardHeight = keyboardVisibleHeight
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
        .onPreferenceChange(TutorialOverlayPreferenceKey.self) { value in
            // Only update if value changed to avoid loops, though Equatable handles it
            self.tutorialData = value
        }
        .overlay(
            Group {
                if let data = tutorialData, data.show {
                    GeometryReader { proxy in
                        // We are already at the screen coordinate space in PersistentBottomSheet (mostly)
                        // But let's use global origin to be safe
                        let globalOrigin = proxy.frame(in: .global).origin
                        
                        ZStack {
                            // Dimmed background with hole
                            Color.black.opacity(0.63)
                                .mask(
                                    ZStack {
                                        Rectangle().fill(Color.black)
                                        
                                        // cutout
                                        RoundedRectangle(cornerRadius: 24)
                                            .frame(width: data.cardFrame.width, height: data.cardFrame.height)
                                            .position(x: data.cardFrame.midX, y: data.cardFrame.midY)
                                            .blendMode(.destinationOut)
                                    }
                                    .compositingGroup()
                                )
                            
                            // Hand icon and text
                            VStack(spacing: -1) {
                                Image("swipe-hand")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height : 80)
                                    .foregroundStyle(.white)
                                    .rotationEffect(.degrees(isAnimatingHand ? 10 : -20))
                                    .offset(x: isAnimatingHand ? 30 : -30, y: 0)
                                    .animation(
                                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                        value: isAnimatingHand
                                    )
                                    .onAppear {
                                        isAnimatingHand = true
                                    }
                                
                                Text("Swipe cards to review each category")
                                    .font(NunitoFont.bold.size(16))
                                    .foregroundStyle(.white)
                            }
                            .offset(x: 0, y: -40)
                            .position(x: data.cardFrame.midX, y: data.cardFrame.maxY + 60)
                        }
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
                        .ignoresSafeArea()
                        .offset(x: -globalOrigin.x, y: -globalOrigin.y)
                    }
                    .zIndex(9999) // Ensure it's on top of everything
                    .allowsHitTesting(false) // Let touches pass through
                }
            }
        )
    }
    
    @ViewBuilder
    private func bottomSheetContainer() -> some View {
        let canSwipeToDismiss = coordinator.currentBottomSheetRoute == .yourCurrentAvatar || coordinator.currentBottomSheetRoute == .setUpAvatarFor
        let dismissThreshold: CGFloat = 120
        let dismissAnimationDistance: CGFloat = 700

        let dragGesture = DragGesture()
            .onChanged { value in
                guard canSwipeToDismiss else { return }
                let t = value.translation.height
                withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.9, blendDuration: 0.1)) {
                    dragOffsetY = max(0, t)
                }
            }
            .onEnded { value in
                guard canSwipeToDismiss else { return }
                let t = value.translation.height
                if t > dismissThreshold {
                    withAnimation(.easeOut(duration: 0.22)) {
                        dragOffsetY = dismissAnimationDistance
                    }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 220_000_000)
                        coordinator.navigateInBottomSheet(.homeDefault)
                        dragOffsetY = 0
                    }
                } else {
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.85, blendDuration: 0.1)) {
                        dragOffsetY = 0
                    }
                }
            }

        let sheet = ZStack(alignment: .bottomTrailing) {
            let _ = print("[PersistentBottomSheet] currentCanvasRoute=\(coordinator.currentCanvasRoute), bottomSheetRoute=\(coordinator.currentBottomSheetRoute)")
            bottomSheetContent(for: coordinator.currentBottomSheetRoute)
                .frame(maxWidth: .infinity, alignment: .top)
            
            if shouldShowOnboardingNextArrow {
                Button(action: handleOnboardingNextTapped) {
                    if familyStore.pendingUploadCount > 0 {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 52, height: 52)
                            .background(
                                Capsule()
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "4CAF50"), Color(hex: "8BC34A")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    } else {
                        GreenCircle()
                    }
                }
                .buttonStyle(.plain)
                .disabled(familyStore.pendingUploadCount > 0)
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
        
        if let height = getBottomSheetHeight() {
            sheet
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(36, corners: [.topLeft, .topRight])
                
                .shadow(color :.grayScale70, radius: 27.5)
                .offset(y: dragOffsetY)
                .gesture(dragGesture)
                
//                .overlay(
//                    LinearGradient(
//                        gradient: Gradient(colors: [
//                            Color.red.opacity(1.0),
//                            Color.red.opacity(0.0)
//                        ]),
//                        startPoint: .bottom,
//                        endPoint: .top
//                    )
//                    .frame(height: 161)
//                    .allowsHitTesting(false)
//                    .offset(y: -120),
//                    alignment: .top
//                )
                .ignoresSafeArea(edges: .bottom)
        } else {
            sheet
                .frame(maxWidth: .infinity, alignment: .top)
                .background(Color.white)
                .cornerRadius(36, corners: [.topLeft, .topRight])
                .shadow(color :.grayScale70, radius: 27.5)
                .offset(y: dragOffsetY)
                .gesture(dragGesture)
//                .shadow(radius: 27.5)
//                .overlay(
//                    LinearGradient(
//                        gradient: Gradient(colors: [
//                            Color.white.opacity(1.0),
//                            Color.white.opacity(0.0)
//                        ]),
//                        startPoint: .bottom,
//                        endPoint: .top
//                    )
//                    .frame(height: 123)
//                    .allowsHitTesting(false)
//                    .offset(y: -23),
//                    alignment: .top
//                )
                .ignoresSafeArea(edges: .bottom)
        }
    }
    
    private func getBottomSheetHeight() -> CGFloat? {
        switch coordinator.currentBottomSheetRoute {
        case .alreadyHaveAnAccount:
            return 275
        case  .doYouHaveAnInviteCode:
            return 241
        case .welcomeBack:
            return 275
        case .enterInviteCode:
            return 397
        case .whosThisFor:
            return 284
        case .letsMeetYourIngrediFam:
            return 397
        case .whatsYourName, .addMoreMembers:
            return 438
        case .addMoreMembersMinimal:
            return 271
        case .editMember:
            return 438
        case .wouldYouLikeToInvite(_, _):
            return 292
        case .wantToAddPreference:
            return 250
        case .generateAvatar:
            return 379
        case .bringingYourAvatar:
            return 316
        case .meetYourAvatar:
            return 391
        case .yourCurrentAvatar:
            return nil
        case .setUpAvatarFor:
            return nil
        case .dietaryPreferencesSheet(let isFamilyFlow):
            return nil
        case .allSetToJoinYourFamily:
            return 284
        // For preference sheets shown from MainCanvasView, let the
        // content determine its own height instead of forcing a static one.
        case .onboardingStep:
            return nil
        case .fineTuneYourExperience:
            return 271
        case .homeDefault:
            return 0
        case .chatIntro:
            return 738
        case .chatConversation:
            return 738
        case .workingOnSummary:
            return 281
        case .meetYourProfileIntro:
            return 200
        case .meetYourProfile:
            return 389
        case .preferencesAddedSuccess:
            return 285
        }
    }
    
    // MARK: - Onboarding next arrow
    
    private var shouldShowOnboardingNextArrow: Bool {
        // Only show the forward arrow when we are on the main onboarding canvas
        // and the bottom sheet is one of the preference questions.
        guard case .mainCanvas = coordinator.currentCanvasRoute else {
            return false
        }
        
        // Show arrow for any onboarding step, but not for fineTuneYourExperience
        if case .onboardingStep = coordinator.currentBottomSheetRoute {
            return true
        }
        return false
    }
    
    private func handleOnboardingNextTapped() {
        Task {
            // Wait for all pending uploads to complete before navigating
            await familyStore.waitForPendingUploads()
            
            await MainActor.run {
                // Get current step ID from route
                guard case .onboardingStep(let currentStepId) = coordinator.currentBottomSheetRoute else {
                    return
                }
                
                // Check if current step is "lifeStyle" → show FineTuneYourExperience
                if currentStepId == "lifeStyle" {
                    coordinator.navigateInBottomSheet(.fineTuneYourExperience)
                    return
                }
                
                // Check if this is the last step → mark as complete, show summary, then IngrediBotView (stay on MainCanvasView)
                if store.isLastStep {
                    // Mark the last section as complete to show 100% progress
                    store.next()
                    coordinator.navigateInBottomSheet(.workingOnSummary)
                    return
                }
                
                // Advance logical onboarding progress (for progress bar & tag bar)
                store.next()
                
                // Move the bottom sheet to the *newly current* onboarding question
                if let newCurrentStepId = store.currentStepId {
                    coordinator.navigateInBottomSheet(.onboardingStep(stepId: newCurrentStepId))
                }
            }
        }
    }
    
    @ViewBuilder
    private func bottomSheetContent(for route: BottomSheetRoute) -> some View {
        switch route {
        case .alreadyHaveAnAccount:
            AlreadyHaveAnAccount {
                coordinator.navigateInBottomSheet(.welcomeBack)
            } noPressed: {
                coordinator.navigateInBottomSheet(.doYouHaveAnInviteCode)
            }
            
        case .welcomeBack:
            WelcomeBack()
            
        case .doYouHaveAnInviteCode:
            DoYouHaveAnInviteCode {
                coordinator.navigateInBottomSheet(.enterInviteCode)
            } noPressed: {
                coordinator.navigateInBottomSheet(.whosThisFor)
            }
            
        case .enterInviteCode:
            EnterYourInviteCode(
                yesPressed: {
                    Task { @MainActor in
                        await authController.signIn()
                        coordinator.showCanvas(.welcomeToYourFamily)
                    }
                },
                noPressed: {
                    coordinator.navigateInBottomSheet(.whosThisFor)
                }
            )
            
        case .whosThisFor:
            WhosThisFor {
                Task { @MainActor in
                    // Guest login already happened on .heyThere screen, just proceed
                    await familyStore.createBiteBuddyFamily()
                    coordinator.showCanvas(.dietaryPreferencesAndRestrictions(isFamilyFlow: false))
                    coordinator.navigateInBottomSheet(.dietaryPreferencesSheet(isFamilyFlow: false))
                }
            } addFamilyPressed: {
                Task { @MainActor in
                    // Guest login already happened on .heyThere screen, just proceed
                    coordinator.showCanvas(.letsMeetYourIngrediFam)
                }
            }
            
        case .letsMeetYourIngrediFam:
            MeetYourIngrediFam {
                // If coming from Settings, user already exists - skip to adding members
                // Otherwise, go to whatsYourName for new family creation
                if coordinator.isCreatingFamilyFromSettings {
                    // User already exists, create pending self member from existing family
                    if let family = familyStore.family {
                        familyStore.setPendingSelfMemberFromExisting(family.selfMember)
                    }
                    coordinator.navigateInBottomSheet(.addMoreMembers)
                } else {
                    coordinator.navigateInBottomSheet(.whatsYourName)
                }
            }
            
        case .whatsYourName:
            WhatsYourName { name in
                 // Async closure wrapper for immediate family creation
                 try await familyStore.createFamilyImmediate(selfName: name)
                 coordinator.navigateInBottomSheet(.addMoreMembers)
            }
            
        case .addMoreMembers:
            AddMoreMembers { name, image, storagePath, color in
                // Async closure wrapper for immediate member addition
                let newMember = try await familyStore.addMemberImmediate(
                    name: name,
                    image: image,
                    storagePath: storagePath,
                    color: color,
                    webService: webService
                )
                
                // If coming from home screen, navigate to WouldYouLikeToInvite
                // Otherwise, navigate to addMoreMembersMinimal (onboarding flow)
                if case .home = coordinator.currentCanvasRoute {
                    coordinator.navigateInBottomSheet(.wouldYouLikeToInvite(memberId: newMember.id, name: name))
                } else {
                    coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
                }
            }
            
        case .addMoreMembersMinimal:
            AddMoreMembersMinimal {
                Task {
                    // If creating family from Settings, add members to existing family
                    // Otherwise, just proceed (family already created incrementally)
                     if coordinator.isCreatingFamilyFromSettings {
                        // Logic handled incrementally now?
                        // If we used `addMemberImmediate` in AddMoreMembers view, they are already added.
                        // But `AddMoreMembersMinimal` manages the list and "Continue".
                        // Wait, `AddMoreMembersMinimal` view uses `familyStore`.
                        // If we are in "Immediate" mode, the members are already in `family.otherMembers`.
                        // `AddMoreMembersMinimal` might be relying on `pendingOtherMembers`.
                        // I need to check `AddMoreMembersMinimal`.
                        
                        // For now, I will assume `AddMoreMembersMinimal` continues navigation.
                        // Existing logic called `createFamilyFromPendingIfNeeded` or `addPendingMembersToExistingFamily`.
                        // Since we are creating IMMEDIATELY, these pending lists should be empty or unused?
                        // `WhatsYourName` clears pending self member.
                        // `AddMoreMembers` (immediate) adds to family directly.
                        // So `pendingOtherMembers` should be empty?
                        // If so, `createFamilyFromPendingIfNeeded` does nothing?
                        // Let's verify.
                        
                        // Whatever we do, we just navigate to dietary preferences.
                    } else {
                        // Family created at WhatsYourName step.
                        // Members added at AddMoreMembers step.
                        // So we just proceed.
                    }
                    coordinator.showCanvas(.dietaryPreferencesAndRestrictions(isFamilyFlow: true))
                }
            } addMorePressed: {
                coordinator.navigateInBottomSheet(.addMoreMembers)
            }
        
        case .editMember(let memberId, let isSelf):
            EditMember(memberId: memberId, isSelf: isSelf) {
                coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
            }
            
        case .wouldYouLikeToInvite(let memberId, let name):
            let _ = print("[PersistentBottomSheet] Rendering .wouldYouLikeToInvite for \(name) (id: \(memberId))")
            WouldYouLikeToInvite(
                name: name,
                isLoading: isGeneratingInviteCode
            ) {
                Task { @MainActor in
                    await handleInviteShare(memberId: memberId)
                }
            } continuePressed: {
                // Maybe later -> do NOT mark pending; only invited members should show "Pending"
                // If this flow was started from Home/Manage Family, dismiss the sheet.
                // Otherwise, keep onboarding behavior.
                isGeneratingInviteCode = false
                if case .home = coordinator.currentCanvasRoute {
                    coordinator.navigateInBottomSheet(.homeDefault)
                } else {
                    coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
                }
            }
            
        case .wantToAddPreference(let name):
            WantToAddPreference(name: name) {
                // Later button pressed - dismiss sheet back to home
                coordinator.navigateInBottomSheet(.homeDefault)
            } yesPressed: {
                // Yes button pressed - reset onboarding and navigate to MainCanvasView with singleMember flow
                store.reset(flowType: .singleMember)
                coordinator.showCanvas(.mainCanvas(flow: .singleMember))
            }
            
        case .generateAvatar:
            GenerateAvatar(
                isExpandedMinimal: $isExpandedMinimal,
                randomPressed: { selection in
                    // Cancel any existing generation task
                    generationTask?.cancel()
                    generationTask = Task {
                        await memojiStore.generate(selection: selection, coordinator: coordinator)
                    }
                },
                generatePressed: { selection in
                    // Cancel any existing generation task
                    generationTask?.cancel()
                    generationTask = Task {
                        await memojiStore.generate(selection: selection, coordinator: coordinator)
                    }
                }
            )
            .onAppear {
                // Reset to collapsed state when appearing
                isExpandedMinimal = false
            }
            
        case .bringingYourAvatar:
            IngrediBotWithText(text: "Bringing your avatar to life... it's going to be awesome!")
            
        case .meetYourAvatar:
            // CRITICAL: Capture image and background color immediately to prevent EXC_BAD_ACCESS
            // This ensures the image is not deallocated while the view is being created
            let capturedImage = memojiStore.image
            let capturedBackgroundColor = memojiStore.backgroundColorHex
            
            MeetYourAvatar(
                image: capturedImage,
                backgroundColorHex: capturedBackgroundColor
            ) {
                coordinator.navigateInBottomSheet(.generateAvatar)
            } assignedPressed: {
                Task {
                    await handleAssignAvatar(
                        memojiStore: memojiStore,
                        familyStore: familyStore
                    )
                    
                    // Navigate back based on where we came from
                    if let previousRoute = memojiStore.previousRouteForGenerateAvatar {
                        // If we came from meetYourProfile, go back there with the same memberId
                        if case .meetYourProfile(let memberId) = previousRoute {
                            coordinator.navigateInBottomSheet(.meetYourProfile(memberId: memberId))
                            memojiStore.previousRouteForGenerateAvatar = nil
                        } else {
                            coordinator.navigateInBottomSheet(previousRoute)
                            memojiStore.previousRouteForGenerateAvatar = nil
                        }
                    } else if case .home = coordinator.currentCanvasRoute {
                        coordinator.navigateInBottomSheet(.homeDefault)
                    } else {
                        coordinator.navigateInBottomSheet(.addMoreMembers)
                    }
                }
            }
            
        case .yourCurrentAvatar:
            YourCurrentAvatar {
                // Ensure GenerateAvatar knows to go back to YourCurrentAvatar when launched from Home/Settings flows
                memojiStore.previousRouteForGenerateAvatar = .yourCurrentAvatar
                coordinator.navigateInBottomSheet(.generateAvatar)
            }
            
        case .setUpAvatarFor:
            SetUpAvatarFor {
                coordinator.navigateInBottomSheet(.yourCurrentAvatar)
            }
            
        case .dietaryPreferencesSheet(let isFamilyFlow):
            DietaryPreferencesSheetContent(isFamilyFlow: isFamilyFlow) {
                // Stop haptic feedback when "Let's Go" is pressed
                NotificationCenter.default.post(name: PhysicsController.stopHapticsNotification, object: nil)
                
                // Get first step ID from JSON dynamically
                let steps = DynamicStepsProvider.loadSteps()
                if let firstStepId = steps.first?.id {
                    coordinator.navigateInBottomSheet(.onboardingStep(stepId: firstStepId))
                }
                coordinator.showCanvas(.mainCanvas(flow: isFamilyFlow ? .family : .individual))
            }
            .onAppear {
                // If the user initiated family creation from Settings, skip the
                // "Personalize your Choices" sheet and auto-advance directly
                // into the first dynamic onboarding step.
                if coordinator.isCreatingFamilyFromSettings {
                    // Stop haptics immediately to avoid lingering feedback
                    NotificationCenter.default.post(name: PhysicsController.stopHapticsNotification, object: nil)

                    // Navigate to the first dynamic step and switch canvas
                    let steps = DynamicStepsProvider.loadSteps()
                    if let firstStepId = steps.first?.id {
                        coordinator.navigateInBottomSheet(.onboardingStep(stepId: firstStepId))
                    }
                    coordinator.showCanvas(.mainCanvas(flow: isFamilyFlow ? .family : .individual))
                }
            }
            
        case .allSetToJoinYourFamily:
            PreferencesAddedSuccessSheet {
                // Check if family creation was initiated from Settings
                if coordinator.isCreatingFamilyFromSettings {
                    // Reset the flag
                    coordinator.isCreatingFamilyFromSettings = false
                    // Navigate back to Home and request a push to Settings
                    coordinator.showCanvas(.home)
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        appState.navigateToSettings = true
                    }
                } else {
                    // Normal flow - go to Home
                    OnboardingPersistence.shared.markCompleted()
                    coordinator.showCanvas(.home)
                }
            }
            
        case .fineTuneYourExperience:
            FineTuneExperience(
                allSetPressed: {
                    coordinator.navigateInBottomSheet(.workingOnSummary)
                },
                addPreferencesPressed: {
                    // Check if there's a next step available before advancing
                    // If lifeStyle is the final step, clicking "Add Preferences" should complete onboarding
                    guard let nextStepId = store.nextStepId else {
                        // No next step available, mark as complete and show summary flow (stay on MainCanvasView)
                        store.next()
                        coordinator.navigateInBottomSheet(.workingOnSummary)
                        return
                    }
                    
                    // Advance logical onboarding progress (for progress bar & tag bar)
                    store.next()
                    
                    // Navigate to the next step
                    coordinator.navigateInBottomSheet(.onboardingStep(stepId: nextStepId))
                }
            )
            
        case .onboardingStep(let stepId):
            // Dynamically load step from JSON using step ID
            if let step = store.step(for: stepId) {
                DynamicOnboardingStepView(
                    step: step,
                    flowType: getOnboardingFlowType(),
                    preferences: $store.preferences
                )
                .padding(.top, 24)
                .padding(.bottom, 80)
            }
        case .chatIntro:
            IngrediBotView()
        case .chatConversation:
            NavigationStack {
                IngrediBotChatView()
            }
            
        case .workingOnSummary:
            IngrediBotWithText(
                text: "Working on your personalized summary…",
                showBackgroundImage: false,
                viewDidAppear: {
                    // After 2 seconds, navigate to chat intro
                    coordinator.navigateInBottomSheet(.chatIntro)
                },
                delay: 2.0
            )
            
        case .homeDefault:
            EmptyView()
            
        case .meetYourProfileIntro:
            MeetYourProfileIntroView()
            
        case .meetYourProfile(let memberId):
            MeetYourProfileView(memberId: memberId) {
                // Check if we're on the family overview screen
                if coordinator.currentCanvasRoute == .letsMeetYourIngrediFam {
                    // If on family overview, just go back to the family overview bottom sheet
                    coordinator.navigateInBottomSheet(.letsMeetYourIngrediFam)
                } else if coordinator.currentCanvasRoute == .home {
                    // If on home screen, close the bottom sheet
                    // If settings sheet was active, it will remain active (it's a separate sheet)
                    coordinator.navigateInBottomSheet(.homeDefault)
                } else if coordinator.isCreatingFamilyFromSettings {
                    // Check if family creation was initiated from Settings
                    coordinator.isCreatingFamilyFromSettings = false
                    // Navigate to home first
                    coordinator.showCanvas(.home)
                    // Then reopen Settings sheet after a brief delay to allow home to load
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                        appState.activeSheet = .settings
                    }
                } else {
                    // Normal onboarding flow - navigate to home
                    OnboardingPersistence.shared.markCompleted()
                    coordinator.showCanvas(.home)
                }
            }
            
        case .preferencesAddedSuccess:
            PreferencesAddedSuccessSheet {
                // If this success sheet was reached while creating family from Settings,
                // return back to Settings instead of proceeding to Meet Your Profile/Home.
                if coordinator.isCreatingFamilyFromSettings {
                    coordinator.isCreatingFamilyFromSettings = false
                    coordinator.showCanvas(.home)
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        appState.navigateToSettings = true
                    }
                } else {
                    coordinator.navigateInBottomSheet(.meetYourProfile(memberId: nil))
                }
            }
        }
    }
    
    private func getOnboardingFlowType() -> OnboardingFlowType {
        // If we are in the main canvas onboarding flow, use the flow type from the route.
        // This ensures that "Just Me" (individual flow) doesn't show family UI even if a family exists.
        if case .mainCanvas(let flow) = coordinator.currentCanvasRoute {
            return flow
        }
        
        // If there are other members in the family, show the family selection carousel
        if let family = familyStore.family, !family.otherMembers.isEmpty {
            return .family
        }
        
        return .individual
    }
    
    // MARK: - INVITES / SHARE

    @MainActor
    private func handleInviteShare(memberId: UUID) async {
        guard !isGeneratingInviteCode else { return }

        isGeneratingInviteCode = true
        defer { isGeneratingInviteCode = false }

        // Invite button pressed - mark member as pending so the UI reflects it
        familyStore.setInvitePendingForPendingOtherMember(id: memberId, pending: true)

        await ensureFamilyExistsForInvitesIfNeeded()

        guard let code = await familyStore.invite(memberId: memberId) else {
            return
        }

        let message = inviteShareMessage(inviteCode: code)
        let items = inviteShareItems(message: message)
        presentShareSheet(items: items)

        routeAfterInviteShare()
    }

    @MainActor
    private func ensureFamilyExistsForInvitesIfNeeded() async {
        // Ensure the family exists before creating invite codes (needed for onboarding flows).
        guard familyStore.family == nil else { return }

        if coordinator.isCreatingFamilyFromSettings {
            await familyStore.addPendingMembersToExistingFamily()
        } else {
            await familyStore.createFamilyFromPendingIfNeeded()
        }
    }

    private func inviteShareMessage(inviteCode: String) -> String {
        let formattedCode = formattedInviteCode(inviteCode)
        return "You've been invited to join my IngrediCheck family.\nSet up your food profile and get personalized ingredient guidance tailored just for you.\n\n📲 Download from the App Store \(appStoreURL) and enter this invite code:\n\(formattedCode)"
    }

    private func formattedInviteCode(_ inviteCode: String) -> String {
        let spaced = inviteCode.map { String($0) }.joined(separator: " ")
        return "**\(spaced)**"
    }

    private func inviteShareItems(message: String) -> [Any] {
        // NOTE: Some share targets (WhatsApp/Instagram, etc.) will drop the text entirely
        // if we include an image in the activity items. To make sure the invite code + link
        // always show, we share the message only.
        [message]
    }

    @MainActor
    private func routeAfterInviteShare() {
        // Return to previous screen or home depending on where we are
        if case .home = coordinator.currentCanvasRoute {
            coordinator.navigateInBottomSheet(.homeDefault)
        } else {
            coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
        }
    }
    
    private func presentShareSheet(items: [Any]) {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            popover.sourceRect = CGRect(
                x: UIScreen.main.bounds.midX,
                y: UIScreen.main.bounds.maxY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }

        root.present(controller, animated: true)
    }
}

// MARK: - Avatar Assignment Helpers

@MainActor
private func handleAssignAvatar(
    memojiStore: MemojiStore,
    familyStore: FamilyStore
) async {
    // CRITICAL: Capture all data immediately to prevent accessing deallocated memory.
    // We no longer re-upload the PNG; instead we use the storage path inside the
    // `memoji-images` bucket returned by the backend.
    guard let storagePath = memojiStore.imageStoragePath, !storagePath.isEmpty else {
        print("[PersistentBottomSheet] handleAssignAvatar: ⚠️ No memoji storage path available, skipping")
        return
    }
    
    // CRITICAL: Capture ALL data immediately to prevent accessing deallocated objects during async operations
    let backgroundColorHex = memojiStore.backgroundColorHex
    let displayName = memojiStore.displayName
    let currentFamily = familyStore.family
    let currentAvatarTargetMemberId = familyStore.avatarTargetMemberId
    let currentPendingSelfMember = familyStore.pendingSelfMember
    let currentPendingOtherMembers = familyStore.pendingOtherMembers
    
    // During onboarding, if avatarTargetMemberId is not set but we have displayName,
    // it means the user generated an avatar without adding the member first.
    // We need to add the member to the pending list first.
    var targetMemberId: UUID? = currentAvatarTargetMemberId
    
    // If no targetMemberId is set but we're in onboarding and have a displayName, add the member
    if targetMemberId == nil,
        currentFamily == nil, // We're in onboarding (no family exists yet)
       let name = displayName,
        !name.isEmpty {
        
        // If we came from MeetYourProfile, check if it's for self member (memberId is nil)
        let isFromProfile: Bool = {
            if case .meetYourProfile(let memberId) = memojiStore.previousRouteForGenerateAvatar {
                return memberId == nil
            }
            return false
        }()
        
        if isFromProfile || currentPendingSelfMember == nil {
            // This is for the self member
            if familyStore.pendingSelfMember == nil {
                print("[PersistentBottomSheet] handleAssignAvatar: No targetMemberId, adding pending self member: \(name)")
                familyStore.setPendingSelfMember(name: name)
            }
            // Re-capture after modification
            if let newSelfMember = familyStore.pendingSelfMember {
                targetMemberId = newSelfMember.id
            }
        } else {
            // This is for an other member
            print("[PersistentBottomSheet] handleAssignAvatar: No targetMemberId, adding pending other member: \(name)")
            familyStore.addPendingOtherMember(name: name)
            // Re-capture after modification
            let updatedPendingMembers = familyStore.pendingOtherMembers
            if !updatedPendingMembers.isEmpty, let lastMember = updatedPendingMembers.last {
                targetMemberId = lastMember.id
            }
        }
    }
    
    guard let targetMemberId = targetMemberId else {
        print("[PersistentBottomSheet] handleAssignAvatar: ⚠️ No avatarTargetMemberId set and couldn't create member, skipping upload")
        return
    }
    
    print("[PersistentBottomSheet] handleAssignAvatar: Starting avatar upload for memberId=\(targetMemberId)")
    
    // CRITICAL: Re-check pending members AFTER potentially adding a new member
    // We need to check the current state because we may have just added a member
    // It's safe to access familyStore properties here since we're in an async function with familyStore as a parameter
    
    // 1. Check if this is a pending self member
    // Check current state first (includes newly added members), fallback to captured state
    if let pendingSelf = familyStore.pendingSelfMember ?? currentPendingSelfMember,
       pendingSelf.id == targetMemberId {
        // This is the pending self member - use setPendingSelfMemberAvatar
        print("[PersistentBottomSheet] handleAssignAvatar: Assigning to pending self member: \(pendingSelf.name)")
        // Set the memoji storage path as imageFileHash and update color to match memoji background.
        await familyStore.setPendingSelfMemberAvatarFromMemoji(
            storagePath: storagePath,
            backgroundColorHex: backgroundColorHex
        )
        print("[PersistentBottomSheet] handleAssignAvatar: ✅ Avatar assigned to pending self member")
        return
    }
    
    // 2. Check if this is a pending other member
    // Check current state first (includes newly added members), fallback to captured state
    let currentPendingOthers = familyStore.pendingOtherMembers
    let pendingOthersToCheck = !currentPendingOthers.isEmpty ? currentPendingOthers : currentPendingOtherMembers
    if let pendingOther = pendingOthersToCheck.first(where: { $0.id == targetMemberId }) {
        // This is a pending other member - use setAvatarForPendingOtherMember
        print("[PersistentBottomSheet] handleAssignAvatar: Assigning to pending other member: \(pendingOther.name)")
        await familyStore.setAvatarForPendingOtherMemberFromMemoji(
            id: targetMemberId,
            storagePath: storagePath,
            backgroundColorHex: backgroundColorHex
        )
        print("[PersistentBottomSheet] handleAssignAvatar: ✅ Avatar assigned to pending other member")
        return
    }
    
    // 3. Otherwise, this is an existing member (from home view) - update directly without re-uploading
    do {
        // 1. Get the member first to access their color for compositing - use captured data
        guard let family = currentFamily else {
            print("[PersistentBottomSheet] handleAssignAvatar: ⚠️ No family loaded, cannot update member")
            return
        }
        
        let allMembers = [family.selfMember] + family.otherMembers
        guard let member = allMembers.first(where: { $0.id == targetMemberId }) else {
            print("[PersistentBottomSheet] handleAssignAvatar: ⚠️ Member \(targetMemberId) not found in family")
            return
        }

        print("[PersistentBottomSheet] handleAssignAvatar: Updating existing member \(member.name) with new avatar...")
        
        // 2. Upload transparent PNG image directly (no compositing - background color stored separately in member.color)
        // Use captured background color if available, otherwise member's existing color
        let bgColor = backgroundColorHex ?? member.color
        print("[PersistentBottomSheet] handleAssignAvatar: Assigning memoji from storagePath=\(storagePath) with background color: \(bgColor)")

        var updatedMember = member
        // Use the memoji storage path as imageFileHash so we can load directly from
        // the `memoji-images` bucket without duplicating the PNG in `productimages`.
        updatedMember.imageFileHash = storagePath
        
        // Also persist the memoji background color as the member's color so
        // small avatars (e.g. in HomeView) use the same color as the
        // MeetYourAvatar sheet.
        // Use captured backgroundColorHex to avoid accessing deallocated object
        if let bgHex = backgroundColorHex, !bgHex.isEmpty {
            // Ensure color has a # prefix (backend check constraint requires it)
            let normalizedColor = bgHex.hasPrefix("#") ? bgHex : "#\(bgHex)"
            print("[PersistentBottomSheet] handleAssignAvatar: Updating member color to memoji background \(normalizedColor) (from \(bgHex))")
            updatedMember.color = normalizedColor
        }
        
        print("[PersistentBottomSheet] handleAssignAvatar: Updating member \(member.name) with imageFileHash=\(storagePath) and color=\(updatedMember.color)")
        
        // 4. Persist the updated member via FamilyStore
        await familyStore.editMember(updatedMember)
        
        // Check if editMember succeeded (it doesn't throw, but sets errorMessage on failure)
        if let errorMsg = familyStore.errorMessage {
            print("[PersistentBottomSheet] handleAssignAvatar: ⚠️ Failed to update member in backend: \(errorMsg)")
            print("[PersistentBottomSheet] handleAssignAvatar: ⚠️ Avatar uploaded but member update failed - imageFileHash may not be persisted")
        } else {
            print("[PersistentBottomSheet] handleAssignAvatar: ✅ Avatar assigned and member updated successfully")
        }
    } catch {
        print("[PersistentBottomSheet] handleAssignAvatar: ❌ Failed to assign avatar: \(error.localizedDescription)")
    }
    
}
