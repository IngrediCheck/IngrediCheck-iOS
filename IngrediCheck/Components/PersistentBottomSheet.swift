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
    @Environment(FoodNotesStore.self) private var foodNotesStore
    @EnvironmentObject private var store: Onboarding
    @State private var keyboardHeight: CGFloat = 0
    @State private var isExpandedMinimal: Bool = false
    @State private var generationTask: Task<Void, Never>?
    @State private var tutorialData: TutorialData? 
    @State private var isAnimatingHand: Bool = false
    @State private var dragOffsetY: CGFloat = 0
    @State private var isGeneratingInviteCode: Bool = false
    @State private var tutorialCardSwipeOffset: CGFloat = 0

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
        
        // Block background interaction when addMoreMembers is open from home screen
        let shouldBlockBackgroundInteraction: Bool = {
            guard case .home = coordinator.currentCanvasRoute else { return false }
            return coordinator.currentBottomSheetRoute == .addMoreMembers
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
            
            // Block all background interactions when addMoreMembers is open from home
            if shouldBlockBackgroundInteraction {
                Color.black
                    .opacity(0.01) // Minimal opacity but still blocks touches
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .allowsHitTesting(true) // Block all touches
            }

            VStack {
                Spacer()
                
                bottomSheetContainer()
            }
            
            // Show loginToContinue as overlay alert when opened from PermissionsCanvas
            if coordinator.currentBottomSheetRoute == .loginToContinue && 
               coordinator.currentCanvasRoute == .whyWeNeedThesePermissions {
                bottomSheetContent(for: .loginToContinue)
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
                Log.debug("PersistentBottomSheet", "Leaving avatar flow, cancelling generation task")
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
            } else if newValue == .homeDefault {
                // Don't reset dragOffsetY when dismissing to homeDefault via drag
                // Keep it at dismiss position to prevent blank sheet flash
            } else if oldValue == .homeDefault && newValue != .homeDefault {
                // Reset dragOffsetY only when presenting a NEW sheet from homeDefault
                dragOffsetY = 0
            } else if oldValue != .homeDefault && newValue != .homeDefault {
                // Transitioning between non-home sheets, reset offset
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
                            // Dimmed background with cutout hole to show original card
                            Color.black.opacity(0.63)
                                .mask(
                                    ZStack {
                                        Rectangle().fill(Color.black)

                                        // cutout to show original card underneath
                                        RoundedRectangle(cornerRadius: 24)
                                            .frame(width: data.cardFrame.width, height: data.cardFrame.height)
                                            .position(x: data.cardFrame.midX, y: data.cardFrame.midY)
                                            .blendMode(.destinationOut)
                                    }
                                    .compositingGroup()
                                )

                            // Redacted dummy card on top of original card (swipeable)
                            TutorialRedactedCard()
                                .frame(width: data.cardFrame.width, height: data.cardFrame.height)
                                .offset(x: tutorialCardSwipeOffset)
                                .rotationEffect(.degrees(tutorialCardSwipeOffset / 30))
                                .position(x: data.cardFrame.midX, y: data.cardFrame.midY)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            tutorialCardSwipeOffset = value.translation.width
                                        }
                                        .onEnded { value in
                                            let threshold: CGFloat = 80
                                            if abs(value.translation.width) > threshold ||
                                               abs(value.predictedEndTranslation.width) > 150 {
                                                // Swipe detected - dismiss overlay
                                                let direction: CGFloat = value.translation.width > 0 ? 1 : -1
                                                withAnimation(.easeOut(duration: 0.3)) {
                                                    tutorialCardSwipeOffset = direction * 400
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    NotificationCenter.default.post(name: .dismissSwipeTutorial, object: nil)
                                                    isAnimatingHand = false
                                                    tutorialCardSwipeOffset = 0
                                                }
                                            } else {
                                                // Snap back
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                                    tutorialCardSwipeOffset = 0
                                                }
                                            }
                                        }
                                )

                            // Hand icon and text
                            VStack(spacing: -1) {
                                Image("swipe-hand")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height : 80)
                                    .foregroundStyle(.white)
                                    .rotationEffect(.degrees(-10))
                                    .offset(x: tutorialCardSwipeOffset * 0.4, y: 0)
                                    .onAppear {
                                        isAnimatingHand = true
                                        // Start auto-swipe animation after a short delay
                                        startTutorialSwipeAnimation()
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Dismiss tutorial on tap anywhere
                            NotificationCenter.default.post(name: .dismissSwipeTutorial, object: nil)
                            isAnimatingHand = false
                            tutorialCardSwipeOffset = 0
                        }
                    }
                    .zIndex(9999) // Ensure it's on top of everything
                    .allowsHitTesting(true) // Allow interactions
                }
            }
        )
    }
    
    @ViewBuilder
    private func bottomSheetContainer() -> some View {
        // Allow swipe to dismiss for avatar sheets and addMoreMembers when opened from home
        let canSwipeToDismiss = coordinator.currentBottomSheetRoute == .yourCurrentAvatar || 
                                coordinator.currentBottomSheetRoute == .setUpAvatarFor ||
                                (coordinator.currentBottomSheetRoute == .addMoreMembers && coordinator.currentCanvasRoute == .home)
        let dismissThreshold: CGFloat = 120
        let dismissAnimationDistance: CGFloat = 700

        // Velocity threshold for dismissal (points per second)
        let velocityThreshold: CGFloat = 500

        let dragGesture = DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard canSwipeToDismiss else { return }
                let t = value.translation.height
                // Direct 1:1 tracking without animation for native feel
                // Add rubber-banding when trying to drag upward (negative values)
                if t < 0 {
                    // Rubber-band effect: diminishing returns when dragging up
                    dragOffsetY = t / 3
                } else {
                    dragOffsetY = t
                }
            }
            .onEnded { value in
                guard canSwipeToDismiss else { return }
                let t = value.translation.height
                let velocity = value.predictedEndTranslation.height - t

                // Dismiss if: dragged past threshold OR fast downward velocity
                let shouldDismiss = t > dismissThreshold || (t > 50 && velocity > velocityThreshold)

                if shouldDismiss {
                    // Calculate animation duration based on remaining distance and velocity
                    let remainingDistance = dismissAnimationDistance - t
                    let baseDuration = 0.25
                    let velocityFactor = min(1.0, max(0.5, 1.0 - (velocity / 2000)))
                    let duration = baseDuration * velocityFactor

                    // Animate sheet down with velocity-aware timing
                    withAnimation(.easeOut(duration: duration)) {
                        dragOffsetY = dismissAnimationDistance
                    }
                    // Navigate after animation completes
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                        coordinator.navigateInBottomSheet(.homeDefault)
                        // Don't reset dragOffsetY here - keep it offscreen to prevent blank sheet flash
                        // It will be reset when a new sheet is presented
                    }
                } else {
                    // Snap back with spring animation (native feel)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0)) {
                        dragOffsetY = 0
                    }
                }
            }

        // Always show quickAccessNeeded in bottom sheet when on PermissionsCanvas
        // Login alert will be shown as overlay independently
        let isOnPermissionsCanvas = coordinator.currentCanvasRoute == .whyWeNeedThesePermissions
        let bottomSheetRouteToShow: BottomSheetRoute = isOnPermissionsCanvas ? .quickAccessNeeded : coordinator.currentBottomSheetRoute
        
        let sheet = ZStack(alignment: .bottomTrailing) {
            let _ = Log.debug("PersistentBottomSheet", "currentCanvasRoute=\(coordinator.currentCanvasRoute), bottomSheetRoute=\(coordinator.currentBottomSheetRoute)")
            bottomSheetContent(for: bottomSheetRouteToShow)
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
        
        if let height = getBottomSheetHeight(for: bottomSheetRouteToShow) {
            sheet
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(36, corners: [.topLeft, .topRight])
                
                .shadow(color: .grayScale70, radius: 27.5)
                .offset(y: dragOffsetY)
                .gesture(dragGesture)
                // Hide sheet when it's being dismissed (offset is beyond screen)
                .opacity(dragOffsetY > 600 ? 0 : 1)
                
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
                .shadow(color: .grayScale70, radius: 27.5)
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
    
    private func getBottomSheetHeight(for route: BottomSheetRoute? = nil) -> CGFloat? {
        let routeToCheck = route ?? coordinator.currentBottomSheetRoute
        switch routeToCheck {
        case .alreadyHaveAnAccount:
            return 244
        case  .doYouHaveAnInviteCode:
            return 220
        case .welcomeBack:
            return 252
        case .enterInviteCode:
            return 380
        case .whosThisFor:
            return 264
        case .letsMeetYourIngrediFam:
            return 397
        case .whatsYourName, .addMoreMembers:
            return 438
        case .addMoreMembersMinimal:
            return 244
        case .editMember:
            return 438
        case .wouldYouLikeToInvite(_, _):
            return 244
        case .addPreferencesForMember(_, _):
            return 300
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
            return 264
        // For preference sheets shown from MainCanvasView, let the
        // content determine its own height instead of forcing a static one.
        case .onboardingStep:
            return nil
        case .fineTuneYourExperience:
            return 244
        case .homeDefault:
            return 0
        case .chatIntro:
            return nil
        case .chatConversation:
            return 450  // Let content determine height dynamically
        case .workingOnSummary:
            return 281
        case .meetYourProfileIntro:
            return 200
        case .meetYourProfile:
            return 397
        case .preferencesAddedSuccess:
            return 264
        case .readyToScanFirstProduct:
            return 244
        case .seeHowScanningWorks:
            return 244
        case .quickAccessNeeded:
            return 220
        case .loginToContinue:
            return 244
        case .updateAvatar(memberId: let memberId):
            return 492
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
                // Reset member filter to "Everyone" for each new onboarding question
                // but preserve the locked member in singleMember flow
                if !coordinator.isAddingPreferencesForMember {
                    familyStore.selectedMemberId = nil
                }

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
                    // Show profile screen first before welcome screen
                    coordinator.isJoiningViaInviteCode = true
                    coordinator.showCanvas(.letsMeetYourIngrediFam)
                    coordinator.navigateInBottomSheet(.meetYourProfile(memberId: nil))
                },
                noPressed: {
                    coordinator.navigateInBottomSheet(.whosThisFor)
                }
            )
            
        case .whosThisFor:
            WhosThisFor {
                // Guest login already happened on .heyThere screen, just proceed
                do {
                    try await familyStore.createBiteBuddyFamily()
                    coordinator.showCanvas(.dietaryPreferencesAndRestrictions(isFamilyFlow: false))
                    coordinator.navigateInBottomSheet(.dietaryPreferencesSheet(isFamilyFlow: false))
                } catch {
                    Log.error("PersistentBottomSheet", "Failed to create Bite Buddy family: \(error)")
                    // Don't navigate forward on error - user stays on current screen
                }
            } addFamilyPressed: {
                // Guest login already happened on .heyThere screen, just proceed
                coordinator.showCanvas(.letsMeetYourIngrediFam)
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
                } else if familyStore.pendingSelfMember != nil || familyStore.family != nil {
                    // Self member already exists (created earlier or family exists)
                    // Skip "What's your name?" and go directly to "Add more members"
                    coordinator.navigateInBottomSheet(.addMoreMembers)
                } else {
                    // No self member yet - show "What's your name?" for initial creation
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
            let _ = Log.debug("PersistentBottomSheet", "Rendering .wouldYouLikeToInvite for \(name) (id: \(memberId))")
            WouldYouLikeToInvite(
                name: name,
                isLoading: isGeneratingInviteCode
            ) {
                Task { @MainActor in
                    await handleInviteShare(memberId: memberId, name: name)
                }
            } continuePressed: {
                // Maybe later -> do NOT mark pending; only invited members should show "Pending"
                // If this flow was started from Home/Manage Family, show "Add preferences?" sheet.
                // Otherwise, keep onboarding behavior.
                isGeneratingInviteCode = false
                if case .home = coordinator.currentCanvasRoute {
                    // Show "Add preferences?" sheet instead of going home
                    coordinator.navigateInBottomSheet(.addPreferencesForMember(memberId: memberId, name: name))
                } else {
                    coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
                }
            }

        case .addPreferencesForMember(let memberId, let name):
            AddPreferencesForMemberSheet(
                name: name,
                laterPressed: {
                    // Reset member selection so other flows default to "Everyone"
                    familyStore.selectedMemberId = nil

                    // Return to origin screen
                    if coordinator.isCreatingFamilyFromSettings {
                        appState.navigate(to: .manageFamily)
                        coordinator.navigateInBottomSheet(.homeDefault)
                    } else {
                        coordinator.navigateInBottomSheet(.homeDefault)
                    }
                },
                yesPressed: {
                    // 1. Set flags to track this flow and origin
                    coordinator.isAddingPreferencesForMember = true
                    coordinator.addPreferencesForMemberId = memberId
                    coordinator.addPreferencesOriginIsSettings = coordinator.isCreatingFamilyFromSettings

                    // 2. Pre-select the member in FamilyStore
                    familyStore.selectedMemberId = memberId

                    // 3. Clear FoodNotesStore state BEFORE reset to prevent
                    // preparePreferencesForMember from saving empty prefs over old cache
                    // and ensure the member starts with a clean slate
                    foodNotesStore.clearCurrentPreferencesOwner()
                    foodNotesStore.clearMemberCache(for: memberId)

                    // 4. Reset onboarding to start fresh for this specific member
                    let memberColor = familyStore.family?.otherMembers.first(where: { $0.id == memberId })?.color
                    store.reset(flowType: .singleMember, memberName: name, memberColor: memberColor)

                    // 4. Navigate to food notes canvas
                    let steps = DynamicStepsProvider.loadSteps()
                    if let firstStepId = steps.first?.id {
                        coordinator.navigateInBottomSheet(.onboardingStep(stepId: firstStepId))
                    }
                    coordinator.showCanvas(.mainCanvas(flow: .singleMember))
                }
            )

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
                await handleAssignAvatar(
                    memojiStore: memojiStore,
                    familyStore: familyStore,
                    webService: webService
                )
                
                // Navigate back based on where we came from
                if let previousRoute = memojiStore.previousRouteForGenerateAvatar {
                    // If we came from meetYourProfile, go back there with the same memberId
                    if case .meetYourProfile(let memberId) = previousRoute {
                        coordinator.navigateInBottomSheet(.meetYourProfile(memberId: memberId))
                        memojiStore.previousRouteForGenerateAvatar = nil
                    } else if case .addMoreMembers = previousRoute {
                        // If we came from AddMoreMembers in onboarding, continue forward to AddMoreMembersMinimal
                        // Otherwise, go back to AddMoreMembers
                        if case .mainCanvas = coordinator.currentCanvasRoute {
                            // In onboarding flow, continue forward
                            coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
                        } else {
                            // Not in onboarding, go back
                            coordinator.navigateInBottomSheet(previousRoute)
                        }
                        memojiStore.previousRouteForGenerateAvatar = nil
                    } else {
                        coordinator.navigateInBottomSheet(previousRoute)
                        memojiStore.previousRouteForGenerateAvatar = nil
                    }
                } else if case .home = coordinator.currentCanvasRoute {
                    coordinator.navigateInBottomSheet(.homeDefault)
                } else if case .mainCanvas = coordinator.currentCanvasRoute {
                    // In onboarding flow without previous route, continue to AddMoreMembersMinimal
                    coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
                } else {
                    coordinator.navigateInBottomSheet(.addMoreMembers)
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
            PreferencesAddedSuccessSheet(title: "All set to join your family!") {
                // Check if this was "add preferences for member" flow
                if coordinator.isAddingPreferencesForMember {
                    let wasFromSettings = coordinator.addPreferencesOriginIsSettings

                    // Reset the flags
                    coordinator.isAddingPreferencesForMember = false
                    coordinator.addPreferencesForMemberId = nil
                    coordinator.addPreferencesOriginIsSettings = false
                    familyStore.selectedMemberId = nil

                    if wasFromSettings {
                        // Return to Manage Family screen
                        coordinator.showCanvas(.home)
                        coordinator.navigateInBottomSheet(.homeDefault)
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            appState.navigate(to: .manageFamily)
                        }
                    } else {
                        // Return to HomeView
                        coordinator.showCanvas(.home)
                        coordinator.navigateInBottomSheet(.homeDefault)
                    }
                    return
                }

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
                    // Normal flow (Add Family): show ScanningHelpSheet
                    coordinator.showCanvas(.seeHowScanningWorks)
                    coordinator.navigateInBottomSheet(.seeHowScanningWorks)
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
            .tint(Color(hex: "#303030"))

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
                // Check if user just joined via invite code - proceed to welcome screen
                if coordinator.isJoiningViaInviteCode {
                    coordinator.isJoiningViaInviteCode = false
                    coordinator.showCanvas(.welcomeToYourFamily)
                } else if coordinator.currentCanvasRoute == .letsMeetYourIngrediFam {
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
                    // Normal flow - in Just Me flow, show ScanningHelpSheet after Meet Your Profile.
                    // In family flow, skip this and go home.
                    if getOnboardingFlowType() == .individual {
                        coordinator.showCanvas(.seeHowScanningWorks)
                        coordinator.navigateInBottomSheet(.seeHowScanningWorks)
                    } else {
                        // Normal onboarding flow - navigate to home
                        OnboardingPersistence.shared.markCompleted()
                        coordinator.showCanvas(.home)
                    }
                }
            }
            
        case .preferencesAddedSuccess:
            PreferencesAddedSuccessSheet {
                // Check if this was "add preferences for member" flow
                if coordinator.isAddingPreferencesForMember {
                    let wasFromSettings = coordinator.addPreferencesOriginIsSettings

                    // Reset the flags
                    coordinator.isAddingPreferencesForMember = false
                    coordinator.addPreferencesForMemberId = nil
                    coordinator.addPreferencesOriginIsSettings = false
                    familyStore.selectedMemberId = nil

                    if wasFromSettings {
                        // Return to Manage Family screen
                        coordinator.showCanvas(.home)
                        coordinator.navigateInBottomSheet(.homeDefault)
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            appState.navigate(to: .manageFamily)
                        }
                    } else {
                        // Return to HomeView
                        coordinator.showCanvas(.home)
                        coordinator.navigateInBottomSheet(.homeDefault)
                    }
                    return
                }

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
                    // After preferences success:
                    // - Just Me flow: show Meet Your Profile
                    // - Add Family flow: go directly to ScanningHelpSheet
                    if getOnboardingFlowType() == .individual {
                        coordinator.navigateInBottomSheet(.meetYourProfile(memberId: nil))
                    } else {
                        coordinator.showCanvas(.seeHowScanningWorks)
                        coordinator.navigateInBottomSheet(.seeHowScanningWorks)
                    }
                }
            }

        case .readyToScanFirstProduct:
            // MARK: - ScanningHelpSheet Feature Flag
            // Set to true to show ScanningHelpSheet in onboarding flow (requires screen recording)
            // Set to false to skip ScanningHelpSheet and go directly to PermissionsCanvas
            // When screen recording is available, change this to true to re-enable the help sheet
            let showScanningHelpSheet = false
            
            ReadyToScanSheet(
                onBack: {
                    if getOnboardingFlowType() == .individual {
                        coordinator.navigateInBottomSheet(.meetYourProfile(memberId: nil))
                    } else {
                        coordinator.showCanvas(.summaryAddFamily)
                        coordinator.navigateInBottomSheet(.allSetToJoinYourFamily)
                    }
                },
                onNotRightNow: {
                    if showScanningHelpSheet {
                        coordinator.showCanvas(.seeHowScanningWorks)
                        coordinator.navigateInBottomSheet(.seeHowScanningWorks)
                    } else {
                        // Skip ScanningHelpSheet and go directly to PermissionsCanvas
                        coordinator.showCanvas(.whyWeNeedThesePermissions)
                        coordinator.navigateInBottomSheet(.quickAccessNeeded)
                    }
                },
                onHaveAProduct: {
                    OnboardingPersistence.shared.markCompleted()
                    coordinator.showCanvas(.home)
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        appState.activeSheet = .scan
                    }
                }
            )

        case .seeHowScanningWorks:
            ScanningHelpSheet(
                onBack: {
                    // Navigate back based on onboarding flow type
                    if getOnboardingFlowType() == .individual {
                        coordinator.showCanvas(.summaryJustMe)
                        coordinator.navigateInBottomSheet(.meetYourProfile(memberId: nil))
                    } else {
                        coordinator.showCanvas(.summaryAddFamily)
                        coordinator.navigateInBottomSheet(.allSetToJoinYourFamily)
                    }
                },
                onGotIt: {
                    coordinator.showCanvas(.whyWeNeedThesePermissions)
                    coordinator.navigateInBottomSheet(.quickAccessNeeded)
                }
            )

        case .quickAccessNeeded:
            // MARK: - ScanningHelpSheet Feature Flag
            // Set to true to show ScanningHelpSheet in onboarding flow (requires screen recording)
            // Set to false to skip ScanningHelpSheet and go directly to PermissionsCanvas
            // When screen recording is available, change this to true to re-enable the help sheet
            let showScanningHelpSheet = false
            
            QuickAccessSheet(
                onBack: {
                    if showScanningHelpSheet {
                        coordinator.showCanvas(.seeHowScanningWorks)
                        coordinator.navigateInBottomSheet(.seeHowScanningWorks)
                    } else {
                        // Skip ScanningHelpSheet and go back to ReadyToScanFirstProduct
                        coordinator.showCanvas(.readyToScanFirstProduct)
                        coordinator.navigateInBottomSheet(.readyToScanFirstProduct)
                    }
                },
                onGoToHome: {
                    OnboardingPersistence.shared.markCompleted()
                    coordinator.showCanvas(.home)
                }
            )

        case .loginToContinue:
            // Show as alert when opened from PermissionsCanvas, otherwise show as sheet
            let showAsAlert = coordinator.currentCanvasRoute == .whyWeNeedThesePermissions
            LoginToContinueSheet(
                onBack: {
                    if showAsAlert {
                        // Just dismiss the alert, keep quickAccessNeeded visible in bottom sheet
                        coordinator.navigateInBottomSheet(.quickAccessNeeded)
                    } else {
                        coordinator.navigateInBottomSheet(.quickAccessNeeded)
                    }
                },
                onSignedIn: {
                    // Stay on the same canvas — just go back to quickAccessNeeded.
                    // The login toggle reflects isSignedIn automatically.
                    coordinator.navigateInBottomSheet(.quickAccessNeeded)
                },
                showAsAlert: showAsAlert
            )
        case .updateAvatar(memberId: let memberId):
            UpdateAvatarSheet(memberId: memberId) {
                // Navigate back to previous route (meetYourProfile or home)
                if case .home = coordinator.currentCanvasRoute {
                    coordinator.navigateInBottomSheet(.homeDefault)
                } else {
                    coordinator.navigateInBottomSheet(.meetYourProfile(memberId: memberId))
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

    // MARK: - Tutorial Animation

    private func startTutorialSwipeAnimation() {
        // Animate the card swiping left repeatedly
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s initial delay

            while tutorialData?.show == true {
                // Swipe left
                withAnimation(.easeInOut(duration: 0.6)) {
                    tutorialCardSwipeOffset = -80
                }
                try? await Task.sleep(nanoseconds: 700_000_000)

                // Return to center
                withAnimation(.easeInOut(duration: 0.6)) {
                    tutorialCardSwipeOffset = 0
                }
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
        }
    }
    
    // MARK: - INVITES / SHARE

    @MainActor
    private func handleInviteShare(memberId: UUID, name: String) async {
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

        routeAfterInviteShare(memberId: memberId, name: name)
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
    private func routeAfterInviteShare(memberId: UUID, name: String) {
        // After sharing invite, show "Add preferences?" sheet if on home screen
        if case .home = coordinator.currentCanvasRoute {
            // Show "Add preferences?" sheet after invite
            coordinator.navigateInBottomSheet(.addPreferencesForMember(memberId: memberId, name: name))
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
    familyStore: FamilyStore,
    webService: WebService
) async {
    // CRITICAL: Capture all data immediately to prevent accessing deallocated memory.
    // We no longer re-upload the PNG; instead we use the storage path inside the
    // `memoji-images` bucket returned by the backend.
    guard let storagePath = memojiStore.imageStoragePath, !storagePath.isEmpty else {
        Log.debug("PersistentBottomSheet", "handleAssignAvatar: ⚠️ No memoji storage path available, skipping")
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

    // Extract memberId from previousRouteForGenerateAvatar if available
    let memberIdFromRoute: UUID? = {
        if case .meetYourProfile(let memberId) = memojiStore.previousRouteForGenerateAvatar {
            return memberId
        }
        return nil
    }()

    // Check if we came from addMoreMembers route (adding a NEW member)
    let isAddingNewMember: Bool = {
        if case .addMoreMembers = memojiStore.previousRouteForGenerateAvatar {
            return true
        }
        return false
    }()

    // If no targetMemberId is set but we have a displayName, we need to create the member
    if targetMemberId == nil,
       let name = displayName,
        !name.isEmpty {

        // If we came from MeetYourProfile, check if it's for self member (memberId is nil)
        let isFromProfileForSelf: Bool = {
            if case .meetYourProfile(let memberId) = memojiStore.previousRouteForGenerateAvatar {
                return memberId == nil
            }
            return false
        }()

        // When family exists and we have a memberId from route, try to use it
        if let family = currentFamily, let routeMemberId = memberIdFromRoute {
            // Family exists and we have a memberId from the route - use it directly
            Log.debug("PersistentBottomSheet", "handleAssignAvatar: Recovering targetMemberId from route: \(routeMemberId)")
            targetMemberId = routeMemberId
        } else if isAddingNewMember {
            // Adding a NEW member from AddMoreMembers flow - create new member
            if currentFamily != nil {
                // Family exists: add member immediately to family
                Log.debug("PersistentBottomSheet", "handleAssignAvatar: Adding new member from AddMoreMembers: \(name)")
                do {
                    let newMember = try await familyStore.addMemberImmediate(
                        name: name,
                        image: nil, // We'll use storagePath instead
                        storagePath: storagePath,
                        color: backgroundColorHex,
                        webService: webService
                    )
                    targetMemberId = newMember.id
                    Log.debug("PersistentBottomSheet", "handleAssignAvatar: ✅ New member created: \(newMember.name)")
                    // Avatar is already assigned via storagePath in addMemberImmediate, so we can return
                    return
                } catch {
                    Log.debug("PersistentBottomSheet", "handleAssignAvatar: ❌ Failed to create new member: \(error.localizedDescription)")
                    ToastManager.shared.show(message: "Failed to add member: \(error.localizedDescription)", type: .error)
                    return
                }
            } else {
                // Onboarding: add to pending
                Log.debug("PersistentBottomSheet", "handleAssignAvatar: Adding pending other member from AddMoreMembers: \(name)")
                familyStore.addPendingOtherMember(name: name)
                let updatedPendingMembers = familyStore.pendingOtherMembers
                if !updatedPendingMembers.isEmpty, let lastMember = updatedPendingMembers.last {
                    targetMemberId = lastMember.id
                }
            }
        } else if isFromProfileForSelf {
            // This is for the self member from MeetYourProfile with nil memberId
            if currentFamily == nil {
                // Onboarding: add to pending
                if familyStore.pendingSelfMember == nil {
                    Log.debug("PersistentBottomSheet", "handleAssignAvatar: No targetMemberId, adding pending self member: \(name)")
                    familyStore.setPendingSelfMember(name: name)
                }
                // Re-capture after modification
                if let newSelfMember = familyStore.pendingSelfMember {
                    targetMemberId = newSelfMember.id
                }
            } else {
                // Family exists but came from MeetYourProfile for self: use selfMember.id
                Log.debug("PersistentBottomSheet", "handleAssignAvatar: Family exists, using selfMember.id for profile update")
                targetMemberId = currentFamily?.selfMember.id
            }
        } else if currentPendingSelfMember == nil && currentFamily == nil {
            // No pending self member and no family - this must be for the self member during onboarding
            Log.debug("PersistentBottomSheet", "handleAssignAvatar: No targetMemberId, adding pending self member: \(name)")
            familyStore.setPendingSelfMember(name: name)
            if let newSelfMember = familyStore.pendingSelfMember {
                targetMemberId = newSelfMember.id
            }
        } else {
            // This is for an other member
            if currentFamily != nil {
                // Family exists: add member immediately to family
                Log.debug("PersistentBottomSheet", "handleAssignAvatar: Family exists, adding member immediately: \(name)")
                do {
                    let newMember = try await familyStore.addMemberImmediate(
                        name: name,
                        image: nil, // We'll use storagePath instead
                        storagePath: storagePath,
                        color: backgroundColorHex,
                        webService: webService
                    )
                    targetMemberId = newMember.id
                    Log.debug("PersistentBottomSheet", "handleAssignAvatar: ✅ Member created successfully: \(newMember.name)")
                    // Avatar is already assigned via storagePath in addMemberImmediate, so we can return
                    // But we should verify the avatar was set correctly
                    return
                } catch {
                    Log.debug("PersistentBottomSheet", "handleAssignAvatar: ❌ Failed to create member: \(error.localizedDescription)")
                    ToastManager.shared.show(message: "Failed to add member: \(error.localizedDescription)", type: .error)
                    return
                }
            } else {
                // Onboarding: add to pending
                Log.debug("PersistentBottomSheet", "handleAssignAvatar: No targetMemberId, adding pending other member: \(name)")
                familyStore.addPendingOtherMember(name: name)
                // Re-capture after modification
                let updatedPendingMembers = familyStore.pendingOtherMembers
                if !updatedPendingMembers.isEmpty, let lastMember = updatedPendingMembers.last {
                    targetMemberId = lastMember.id
                }
            }
        }
    }
    
    guard let targetMemberId = targetMemberId else {
        Log.debug("PersistentBottomSheet", "handleAssignAvatar: ⚠️ No avatarTargetMemberId set and couldn't create member, skipping upload")
        ToastManager.shared.show(message: "Unable to assign avatar. Please enter a name and try again.", type: .error)
        return
    }
    
    Log.debug("PersistentBottomSheet", "handleAssignAvatar: Starting avatar upload for memberId=\(targetMemberId)")
    
    // CRITICAL: Re-check pending members AFTER potentially adding a new member
    // We need to check the current state because we may have just added a member
    // It's safe to access familyStore properties here since we're in an async function with familyStore as a parameter
    
    // 1. Check if this is a pending self member
    // Check current state first (includes newly added members), fallback to captured state
    if let pendingSelf = familyStore.pendingSelfMember ?? currentPendingSelfMember,
       pendingSelf.id == targetMemberId {
        // This is the pending self member - use setPendingSelfMemberAvatar
        Log.debug("PersistentBottomSheet", "handleAssignAvatar: Assigning to pending self member: \(pendingSelf.name)")
        // Set the memoji storage path as imageFileHash and update color to match memoji background.
        await familyStore.setPendingSelfMemberAvatarFromMemoji(
            storagePath: storagePath,
            backgroundColorHex: backgroundColorHex
        )
        Log.debug("PersistentBottomSheet", "handleAssignAvatar: ✅ Avatar assigned to pending self member")
        return
    }
    
    // 2. Check if this is a pending other member
    // Check current state first (includes newly added members), fallback to captured state
    let currentPendingOthers = familyStore.pendingOtherMembers
    let pendingOthersToCheck = !currentPendingOthers.isEmpty ? currentPendingOthers : currentPendingOtherMembers
    if let pendingOther = pendingOthersToCheck.first(where: { $0.id == targetMemberId }) {
        // This is a pending other member
        Log.debug("PersistentBottomSheet", "handleAssignAvatar: Assigning to pending other member: \(pendingOther.name)")
        
        // If family exists, add the member to the family first, then assign avatar
        if let family = currentFamily {
            Log.debug("PersistentBottomSheet", "handleAssignAvatar: Family exists, adding pending member to family")
            do {
                let newMember = try await familyStore.addMemberImmediate(
                    name: pendingOther.name,
                    image: nil,
                    storagePath: storagePath,
                    color: backgroundColorHex ?? pendingOther.color,
                    webService: webService
                )
                Log.debug("PersistentBottomSheet", "handleAssignAvatar: ✅ Member added to family and avatar assigned: \(newMember.name)")
                // Avatar is already assigned via storagePath in addMemberImmediate
                return
            } catch {
                Log.debug("PersistentBottomSheet", "handleAssignAvatar: ❌ Failed to add pending member to family: \(error.localizedDescription)")
                ToastManager.shared.show(message: "Failed to add member: \(error.localizedDescription)", type: .error)
                return
            }
        } else {
            // Onboarding: just assign avatar to pending member
            await familyStore.setAvatarForPendingOtherMemberFromMemoji(
                id: targetMemberId,
                storagePath: storagePath,
                backgroundColorHex: backgroundColorHex
            )
            Log.debug("PersistentBottomSheet", "handleAssignAvatar: ✅ Avatar assigned to pending other member")
            return
        }
    }
    
    // 3. Otherwise, this is an existing member (from home view) - update directly without re-uploading
    do {
        // 1. Get the member first to access their color for compositing - use captured data
        guard let family = currentFamily else {
            Log.debug("PersistentBottomSheet", "handleAssignAvatar: ⚠️ No family loaded, cannot update member")
            ToastManager.shared.show(message: "Unable to assign avatar. Family not found.", type: .error)
            return
        }
        
        let allMembers = [family.selfMember] + family.otherMembers
        guard let member = allMembers.first(where: { $0.id == targetMemberId }) else {
            Log.debug("PersistentBottomSheet", "handleAssignAvatar: ⚠️ Member \(targetMemberId) not found in family")
            ToastManager.shared.show(message: "Unable to assign avatar. Member not found.", type: .error)
            return
        }

        Log.debug("PersistentBottomSheet", "handleAssignAvatar: Updating existing member \(member.name) with new avatar...")
        
        // 2. Upload transparent PNG image directly (no compositing - background color stored separately in member.color)
        // Use captured background color if available, otherwise member's existing color
        let bgColor = backgroundColorHex ?? member.color
        Log.debug("PersistentBottomSheet", "handleAssignAvatar: Assigning memoji from storagePath=\(storagePath) with background color: \(bgColor)")

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
            Log.debug("PersistentBottomSheet", "handleAssignAvatar: Updating member color to memoji background \(normalizedColor) (from \(bgHex))")
            updatedMember.color = normalizedColor
        }
        
        Log.debug("PersistentBottomSheet", "handleAssignAvatar: Updating member \(member.name) with imageFileHash=\(storagePath) and color=\(updatedMember.color)")
        
        // 4. Persist the updated member via FamilyStore
        await familyStore.editMember(updatedMember)
        
        // Check if editMember succeeded (it doesn't throw, but sets errorMessage on failure)
        if let errorMsg = familyStore.errorMessage {
            Log.debug("PersistentBottomSheet", "handleAssignAvatar: ⚠️ Failed to update member in backend: \(errorMsg)")
            Log.debug("PersistentBottomSheet", "handleAssignAvatar: ⚠️ Avatar uploaded but member update failed - imageFileHash may not be persisted")
            ToastManager.shared.show(message: "Failed to update member: \(errorMsg)", type: .error)
        } else {
            Log.debug("PersistentBottomSheet", "handleAssignAvatar: ✅ Avatar assigned and member updated successfully")
        }
    } catch {
        Log.debug("PersistentBottomSheet", "handleAssignAvatar: ❌ Failed to assign avatar: \(error.localizedDescription)")
        ToastManager.shared.show(message: "Failed to assign avatar: \(error.localizedDescription)", type: .error)
    }

}

// MARK: - Tutorial Redacted Card

/// A redacted/skeleton card view used in the swipe tutorial overlay
private struct TutorialRedactedCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                // Redacted title
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 100, height: 20)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 30, height: 14)
                }

                // Redacted subtitle
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.12))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 200, height: 12)
                }
            }

            // Redacted chips
            FlowLayout(horizontalSpacing: 4, verticalSpacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    let widths: [CGFloat] = [80, 110, 95, 120]
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.5))
                        .frame(width: widths[index], height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            ZStack {
                Color(hex: "FFEB84")

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image("leaf-recycle")
                            .opacity(0.3)
                    }
                }
                .padding(.trailing, 10)
                .offset(y: 17)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

/// Preview wrapper with animation state
private struct TutorialOverlayPreview: View {
    @State private var swipeOffset: CGFloat = 0
    @State private var isShowing: Bool = true

    private let cardWidth = UIScreen.main.bounds.width - 40
    private let cardHeight = UIScreen.main.bounds.height * 0.33

    var body: some View {
        ZStack {
            // Simulated original card underneath (what would show through cutout)
            Color(hex: "FFEB84")
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Oils & Fats")
                            .font(.system(size: 20, weight: .regular))
                        Text("Mark oils you prefer to avoid...")
                            .font(.system(size: 12))
                            .opacity(0.8)
                    }
                    .padding(12),
                    alignment: .topLeading
                )

            // Dark overlay with cutout
            Color.black.opacity(0.63)
                .ignoresSafeArea()
                .mask(
                    ZStack {
                        Rectangle().fill(Color.black)
                        RoundedRectangle(cornerRadius: 24)
                            .frame(width: cardWidth, height: cardHeight)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                )

            // Redacted card on top (swipeable)
            TutorialRedactedCard()
                .frame(width: cardWidth, height: cardHeight)
                .offset(x: swipeOffset)
                .rotationEffect(.degrees(swipeOffset / 30))

            // Hand icon and text overlay
            VStack(spacing: -1) {
                Image("swipe-hand")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-10))
                    .offset(x: swipeOffset * 0.4, y: 0)

                Text("Swipe cards to review each category")
                    .font(NunitoFont.bold.size(16))
                    .foregroundStyle(.white)
            }
            .offset(y: UIScreen.main.bounds.height * 0.25)
        }
        .onAppear {
            startSwipeAnimation()
        }
    }

    private func startSwipeAnimation() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)

            while isShowing {
                // Swipe left
                withAnimation(.easeInOut(duration: 0.6)) {
                    swipeOffset = -80
                }
                try? await Task.sleep(nanoseconds: 700_000_000)

                // Return to center
                withAnimation(.easeInOut(duration: 0.6)) {
                    swipeOffset = 0
                }
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
        }
    }
}

#Preview("Tutorial Overlay with Animation") {
    TutorialOverlayPreview()
}

#Preview("Redacted Card Only") {
    TutorialRedactedCard()
        .frame(width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.height * 0.33)
        .padding()
}
