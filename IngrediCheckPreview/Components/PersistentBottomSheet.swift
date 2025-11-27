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
        case .allergies,
             .intolerances,
             .healthConditions,
             .lifeStage,
             .region,
             .avoid,
             .lifeStyle,
             .nutrition,
             .ethical,
             .taste:
            return nil
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
        
        switch coordinator.currentBottomSheetRoute {
        case .allergies,
             .intolerances,
             .healthConditions,
             .lifeStage,
             .region,
             .avoid,
             .lifeStyle,
             .nutrition,
             .ethical,
             .taste:
            return true
        default:
            return false
        }
    }
    
    private func handleOnboardingNextTapped() {
        // Last question → go to Home
        if coordinator.currentBottomSheetRoute == .taste {
            coordinator.showCanvas(.home)
            return
        }
        
        // Advance logical onboarding progress (for progress bar & tag bar)
        store.next()
        
        // Move the bottom sheet to the next onboarding question
        switch coordinator.currentBottomSheetRoute {
        case .allergies:
            coordinator.navigateInBottomSheet(.intolerances)
        case .intolerances:
            coordinator.navigateInBottomSheet(.healthConditions)
        case .healthConditions:
            coordinator.navigateInBottomSheet(.lifeStage)
        case .lifeStage:
            coordinator.navigateInBottomSheet(.region)
        case .region:
            coordinator.navigateInBottomSheet(.avoid)
        case .avoid:
            coordinator.navigateInBottomSheet(.lifeStyle)
        case .lifeStyle:
            coordinator.navigateInBottomSheet(.nutrition)
        case .nutrition:
            coordinator.navigateInBottomSheet(.ethical)
        case .ethical:
            coordinator.navigateInBottomSheet(.taste)
        default:
            break
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
                coordinator.navigateInBottomSheet(.allergies)
                coordinator.showCanvas(.mainCanvas(flow: isFamilyFlow ? .family : .individual))
            }
            
        case .allSetToJoinYourFamily:
            AllSetToJoinYourFamily {
                coordinator.showCanvas(.home)
            }
            
        case .allergies:
            if let step = store.step(for: .allergies) {
                DynamicOnboardingStepView(
                    step: step,
                    flowType: getOnboardingFlowType(),
                    preferences: $store.preferences
                )
                .padding(.top, 24)
                .padding(.bottom, 80)
            }
            
        case .intolerances:
            if let step = store.step(for: .intolerances) {
                DynamicOnboardingStepView(
                    step: step,
                    flowType: getOnboardingFlowType(),
                    preferences: $store.preferences
                )
                .padding(.top, 24)
                .padding(.bottom, 80)
            }
            
        case .healthConditions:
            if let step = store.step(for: .healthConditions) {
                DynamicOnboardingStepView(
                    step: step,
                    flowType: getOnboardingFlowType(),
                    preferences: $store.preferences
                )
                .padding(.top, 24)
                .padding(.bottom, 80)
            }
            
        case .lifeStage:
            if let step = store.step(for: .lifeStage) {
                DynamicOnboardingStepView(
                    step: step,
                    flowType: getOnboardingFlowType(),
                    preferences: $store.preferences
                )
                .padding(.top, 24)
                .padding(.bottom, 80)
            }
            
        case .region:
            if let step = store.step(for: .region) {
                DynamicOnboardingStepView(
                    step: step,
                    flowType: getOnboardingFlowType(),
                    preferences: $store.preferences
                )
                .padding(.top, 24)
                .padding(.bottom, 80)
            }
            
        case .avoid:
            if let step = store.step(for: .avoid) {
                DynamicOnboardingStepView(
                    step: step,
                    flowType: getOnboardingFlowType(),
                    preferences: $store.preferences
                )
                .padding(.top, 24)
                .padding(.bottom, 80)
            }
            
        case .lifeStyle:
            if let step = store.step(for: .lifeStyle) {
                DynamicOnboardingStepView(
                    step: step,
                    flowType: getOnboardingFlowType(),
                    preferences: $store.preferences
                )
                .padding(.top, 24)
                .padding(.bottom, 80)
            }
            
        case .nutrition:
            if let step = store.step(for: .nutrition) {
                DynamicOnboardingStepView(
                    step: step,
                    flowType: getOnboardingFlowType(),
                    preferences: $store.preferences
                )
                .padding(.top, 24)
                .padding(.bottom, 80)
            }
            
        case .ethical:
            if let step = store.step(for: .ethical) {
                DynamicOnboardingStepView(
                    step: step,
                    flowType: getOnboardingFlowType(),
                    preferences: $store.preferences
                )
                .padding(.top, 24)
                .padding(.bottom, 80)
            }
            
        case .taste:
            if let step = store.step(for: .taste) {
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

