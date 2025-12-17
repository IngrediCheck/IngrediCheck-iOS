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
    @Environment(FamilyStore.self) private var familyStore
    @Environment(MemojiStore.self) private var memojiStore
    @Environment(WebService.self) private var webService
    @EnvironmentObject private var store: Onboarding
    @State private var keyboardHeight: CGFloat = 0
    @State private var isExpandedMinimal: Bool = false
    
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
    }
    
    @ViewBuilder
    private func bottomSheetContainer() -> some View {
        let sheet = ZStack(alignment: .bottomTrailing) {
            let _ = print("[PersistentBottomSheet] currentCanvasRoute=\(coordinator.currentCanvasRoute), bottomSheetRoute=\(coordinator.currentBottomSheetRoute)")
            bottomSheetContent(for: coordinator.currentBottomSheetRoute)
                .frame(maxWidth: .infinity, alignment: .top)
            
            if shouldShowOnboardingNextArrow {
                Button(action: handleOnboardingNextTapped) {
                    GreenCircle()
                }
                .buttonStyle(.plain)
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
                .shadow(radius: 27.5)
                .ignoresSafeArea(edges: .bottom)
        } else {
            sheet
                .frame(maxWidth: .infinity, alignment: .top)
                .background(Color.white)
                .cornerRadius(36, corners: [.topLeft, .topRight])
                .shadow(radius: 27.5)
                .ignoresSafeArea(edges: .bottom)
        }
    }
    
    private func getBottomSheetHeight() -> CGFloat? {
        switch coordinator.currentBottomSheetRoute {
        case .alreadyHaveAnAccount, .doYouHaveAnInviteCode:
            return 275
        case .welcomeBack:
            return 291
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
        case .wouldYouLikeToInvite:
            return 250
        case .wantToAddPreference:
            return 250
        case .generateAvatar:
            return 379
        case .bringingYourAvatar:
            return 282
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
                    coordinator.showCanvas(.welcomeToYourFamily)
                },
                noPressed: {
                    coordinator.navigateInBottomSheet(.whosThisFor)
                }
            )
            
        case .whosThisFor:
            WhosThisFor {
                coordinator.showCanvas(.dietaryPreferencesAndRestrictions(isFamilyFlow: false))
                coordinator.navigateInBottomSheet(.dietaryPreferencesSheet(isFamilyFlow: false))
            } addFamilyPressed: {
                coordinator.showCanvas(.letsMeetYourIngrediFam)
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
                    coordinator.navigateInBottomSheet(.wouldYouLikeToInvite(name: name))
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
            
        case .wouldYouLikeToInvite(let name):
            WouldYouLikeToInvite(name: name) {
                // Invite button pressed - TODO: Implement invite functionality
                coordinator.navigateInBottomSheet(.homeDefault)
            } continuePressed: {
                // Continue button pressed - navigate to WantToAddPreference
                coordinator.navigateInBottomSheet(.wantToAddPreference(name: name))
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
                    Task {
                        await memojiStore.generate(selection: selection, coordinator: coordinator)
                    }
                },
                generatePressed: { selection in
                    Task {
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
            MeetYourAvatar(
                image: memojiStore.image,
                backgroundColorHex: memojiStore.backgroundColorHex
            ) {
                coordinator.navigateInBottomSheet(.generateAvatar)
            } assignedPressed: {
                Task {
                    await handleAssignAvatar(
                        memojiStore: memojiStore,
                        familyStore: familyStore,
                        webService: webService
                    )
                    
                    // If opened from home screen, dismiss the sheet
                    // Otherwise, navigate to addMoreMembersMinimal (onboarding flow)
                    if case .home = coordinator.currentCanvasRoute {
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
                    coordinator.showCanvas(.home)
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
        }
    }
    
    private func getOnboardingFlowType() -> OnboardingFlowType {
        if case .mainCanvas(let flow) = coordinator.currentCanvasRoute {
            return flow
        }
        return .individual
    }
}

// MARK: - Avatar Assignment Helpers

@MainActor
private func handleAssignAvatar(
    memojiStore: MemojiStore,
    familyStore: FamilyStore,
    webService: WebService
) async {
    guard let image = memojiStore.image else {
        print("[PersistentBottomSheet] handleAssignAvatar: ⚠️ No memoji image to upload, skipping")
        return
    }
    
    guard let targetMemberId = familyStore.avatarTargetMemberId else {
        print("[PersistentBottomSheet] handleAssignAvatar: ⚠️ No avatarTargetMemberId set, skipping upload")
        return
    }
    
    print("[PersistentBottomSheet] handleAssignAvatar: Starting avatar upload for memberId=\(targetMemberId)")
    
    do {
        // 1. Upload the avatar image to Supabase and get an imageFileHash
        let imageFileHash = try await webService.uploadImage(image: image)
        print("[PersistentBottomSheet] handleAssignAvatar: ✅ Uploaded avatar, imageFileHash=\(imageFileHash)")
        
        // 2. Find the matching FamilyMember and update its imageFileHash
        guard let family = familyStore.family else {
            print("[PersistentBottomSheet] handleAssignAvatar: ⚠️ No family loaded, cannot update member")
            return
        }
        
        let allMembers = [family.selfMember] + family.otherMembers
        guard let member = allMembers.first(where: { $0.id == targetMemberId }) else {
            print("[PersistentBottomSheet] handleAssignAvatar: ⚠️ Member not found in current family for id=\(targetMemberId)")
            return
        }
        
        var updatedMember = member
        updatedMember.imageFileHash = imageFileHash
        
        // Also persist the memoji background color as the member's color so
        // small avatars (e.g. in HomeView) use the same color as the
        // MeetYourAvatar sheet.
        if let bgHex = memojiStore.backgroundColorHex, !bgHex.isEmpty {
            // Ensure color has a # prefix (backend check constraint requires it)
            let normalizedColor = bgHex.hasPrefix("#") ? bgHex : "#\(bgHex)"
            print("[PersistentBottomSheet] handleAssignAvatar: Updating member color to memoji background \(normalizedColor) (from \(bgHex))")
            updatedMember.color = normalizedColor
        }
        
        print("[PersistentBottomSheet] handleAssignAvatar: Updating member \(member.name) with imageFileHash=\(imageFileHash) and color=\(updatedMember.color)")
        
        // 3. Persist the updated member via FamilyStore
        await familyStore.editMember(updatedMember)
        
        // Check if editMember succeeded (it doesn't throw, but sets errorMessage on failure)
        if let errorMsg = familyStore.errorMessage {
            print("[PersistentBottomSheet] handleAssignAvatar: ⚠️ Failed to update member in backend: \(errorMsg)")
            print("[PersistentBottomSheet] handleAssignAvatar: ⚠️ Avatar uploaded but member update failed - imageFileHash may not be persisted")
        } else {
            print("[PersistentBottomSheet] handleAssignAvatar: ✅ Avatar assigned and member updated successfully")
        }
    } catch {
        print("[PersistentBottomSheet] handleAssignAvatar: ❌ Failed to upload or assign avatar: \(error.localizedDescription)")
    }
}

