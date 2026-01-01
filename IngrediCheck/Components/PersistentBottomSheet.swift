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
    @EnvironmentObject private var store: Onboarding
    @State private var keyboardHeight: CGFloat = 0
    @State private var isExpandedMinimal: Bool = false
    @State private var generationTask: Task<Void, Never>?
    @State private var tutorialData: TutorialData? 
    @State private var isAnimatingHand: Bool = false
    
    var body: some View {
        @Bindable var coordinator = coordinator
        @Bindable var memojiStore = memojiStore
        
        VStack {
            Spacer()
            
            bottomSheetContainer()
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
            return 540
        case .chatConversation:
            return UIScreen.main.bounds.height * 0.75
        case .workingOnSummary:
            return 250
        case .meetYourProfileIntro:
            return 200
        case .meetYourProfile:
            return 389
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
                
                // Move the bottom sheet to the next onboarding question using JSON order
                if let nextStepId = store.nextStepId {
                    coordinator.navigateInBottomSheet(.onboardingStep(stepId: nextStepId))
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
                coordinator.navigateInBottomSheet(.whatsYourName)
            }
            
        case .whatsYourName:
            WhatsYourName {
                coordinator.navigateInBottomSheet(.addMoreMembers)
            }
            
        case .addMoreMembers:
            AddMoreMembers { name in
                // If coming from home screen, navigate to WouldYouLikeToInvite
                // Otherwise, navigate to addMoreMembersMinimal (onboarding flow)
                if case .home = coordinator.currentCanvasRoute {
                    if let newId = familyStore.pendingOtherMembers.last?.id {
                        coordinator.navigateInBottomSheet(.wouldYouLikeToInvite(memberId: newId, name: name))
                    } else {
                        coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
                    }
                } else {
                    coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
                }
            }
            
        case .addMoreMembersMinimal:
            AddMoreMembersMinimal {
                Task {
                    await familyStore.createFamilyFromPendingIfNeeded()
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
            WouldYouLikeToInvite(name: name) {
                // Invite button pressed - mark member as pending so the UI reflects it
                familyStore.setInvitePendingForPendingOtherMember(id: memberId, pending: true)
                
                // If this is a real family (not just pending onboarding members), call the invite API
                if familyStore.family != nil {
                    Task {
                        _ = await familyStore.invite(memberId: memberId)
                    }
                }
                
                // Return to previous screen or home depending on where we are
                if case .home = coordinator.currentCanvasRoute {
                    coordinator.navigateInBottomSheet(.homeDefault)
                } else {
                    coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
                }
            } continuePressed: {
                // Maybe later -> mark member as pending and go back to minimal add members screen
                familyStore.setInvitePendingForPendingOtherMember(id: memberId, pending: true)
                coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
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
                        // If we came from meetYourProfile, go back there
                        if case .meetYourProfile = previousRoute {
                            coordinator.navigateInBottomSheet(.meetYourProfile)
                            memojiStore.previousRouteForGenerateAvatar = nil
                        } else {
                            coordinator.navigateInBottomSheet(previousRoute)
                            memojiStore.previousRouteForGenerateAvatar = nil
                        }
                    } else if case .home = coordinator.currentCanvasRoute {
                        coordinator.navigateInBottomSheet(.homeDefault)
                    } else {
                        coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
                    }
                }
            }
            
        case .yourCurrentAvatar:
            YourCurrentAvatar {
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
            
        case .allSetToJoinYourFamily:
            AllSetToJoinYourFamily {
                coordinator.showCanvas(.home)
            }
            
        case .fineTuneYourExperience:
            FineTuneExperience(
                allSetPressed: {
                    // Only show meetYourProfile flow for individual (Just Me) users
                    let flowType = getOnboardingFlowType()
                    if flowType == .individual {
                        coordinator.navigateInBottomSheet(.meetYourProfileIntro)
                    } else {
                        coordinator.navigateInBottomSheet(.workingOnSummary)
                    }
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
                viewDidAppear: {
                    // After 2 seconds, navigate to IngrediBotView
                    coordinator.navigateInBottomSheet(.chatIntro)
                },
                delay: 2.0
            )
            
        case .homeDefault:
            EmptyView()
            
        case .meetYourProfileIntro:
            MeetYourProfileIntroView()
            
        case .meetYourProfile:
            MeetYourProfileView {
            	    coordinator.showCanvas(.home)
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
        
        // Check if this is for self member or other member
        // If there's no pending self member, this must be for self
        // Otherwise, it's for an other member
        if currentPendingSelfMember == nil {
            // This is for the self member
            print("[PersistentBottomSheet] handleAssignAvatar: No targetMemberId, adding pending self member: \(name)")
            familyStore.setPendingSelfMember(name: name)
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
            print("[PersistentBottomSheet] handleAssignAvatar: ⚠️ Member not found in current family for id=\(targetMemberId)")
            return
        }
        
        // 2. Upload transparent PNG image directly (no compositing - background color stored separately in member.color)
        // Use captured background color if available, otherwise use member's existing color
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
