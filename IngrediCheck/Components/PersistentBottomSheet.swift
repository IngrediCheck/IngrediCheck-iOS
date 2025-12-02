//
//  PersistentBottomSheet.swift
//  IngrediCheckPreview
//
//  Created on 13/11/25.
//

import SwiftUI

struct PersistentBottomSheet: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @EnvironmentObject private var store: Onboarding
    
    var body: some View {
        @Bindable var coordinator = coordinator
        
        VStack {
            Spacer()
            
            bottomSheetContainer()
        }
        .background(
            .clear
        )
        .ignoresSafeArea(edges: .bottom)
    }
    
    @ViewBuilder
    private func bottomSheetContainer() -> some View {
        let sheet = ZStack(alignment: .bottomTrailing) {
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
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .shadow(radius: 27.5)
                .ignoresSafeArea(edges: .bottom)
        } else {
            sheet
                .frame(maxWidth: .infinity, alignment: .top)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
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
        case .generateAvatar:
            return 642
        case .bringingYourAvatar:
            return 282
        case .meetYourAvatar:
            return 391
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
        
        // Check if this is the last step → go to Home
        if store.isLastStep {
            coordinator.showCanvas(.home)
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
            EnterYourInviteCode(yesPressed: {
                coordinator.showCanvas(.welcomeToYourFamily)
            })
            
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
                coordinator.navigateInBottomSheet(.generateAvatar)
            } addMemberPressed: {
                coordinator.navigateInBottomSheet(.addMoreMembers)
            }
            
        case .addMoreMembers:
            AddMoreMembers {
                coordinator.navigateInBottomSheet(.generateAvatar)
            } addMemberPressed: {
                coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
            }
            
        case .addMoreMembersMinimal:
            AddMoreMembersMinimal {
                coordinator.showCanvas(.dietaryPreferencesAndRestrictions(isFamilyFlow: true))
            } addMorePressed: {
                coordinator.navigateInBottomSheet(.addMoreMembers)
            }
            
        case .generateAvatar:
            GenerateAvatar(isExpandedMinimal: .constant(false))
            
        case .bringingYourAvatar:
            BringingYourAvatar {
                coordinator.navigateInBottomSheet(.meetYourAvatar)
            }
            
        case .meetYourAvatar:
            MeetYourAvatar {
                coordinator.navigateInBottomSheet(.bringingYourAvatar)
            } assignedPressed: {
                coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
            }
            
        case .dietaryPreferencesSheet(let isFamilyFlow):
            DietaryPreferencesSheetContent(isFamilyFlow: isFamilyFlow) {
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
            FineTuneYourExperience(
                allSetPressed: {
                    coordinator.showCanvas(.home)
                },
                addPreferencesPressed: {
                    // Check if there's a next step available before advancing
                    // If lifeStyle is the final step, clicking "Add Preferences" should complete onboarding
                    guard let nextStepId = store.nextStepId else {
                        // No next step available, complete onboarding by going to home
                        coordinator.showCanvas(.home)
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
            IngrediBotChatView()
            
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

