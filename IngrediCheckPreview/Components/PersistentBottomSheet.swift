//
//  PersistentBottomSheet.swift
//  IngrediCheckPreview
//
//  Created on 13/11/25.
//

import SwiftUI

struct PersistentBottomSheet: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    
    var body: some View {
        @Bindable var coordinator = coordinator
        
        VStack {
            Spacer()
            
            ZStack {
                bottomSheetContent(for: coordinator.currentBottomSheetRoute)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(height: getBottomSheetHeight())
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .shadow(radius: 27.5)
            .ignoresSafeArea(edges: .bottom)
        }
        .background(
            .clear
        )
        .ignoresSafeArea(edges: .bottom)
    }
    
    private func getBottomSheetHeight() -> CGFloat {
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
            return isFamilyFlow ? 501 : 351
        case .allSetToJoinYourFamily:
            return 284
        case .allergies:
            return coordinator.onboardingFlow == .family ? 520 : 420
        case .intolerances:
            return coordinator.onboardingFlow == .family ? 520 : 420
        case .healthConditions:
            return coordinator.onboardingFlow == .family ? 520 : 420
        case .lifeStage:
            return coordinator.onboardingFlow == .family ? 480 : 400
        case .region:
            return coordinator.onboardingFlow == .family ? 480 : 400
        case .avoid:
            return coordinator.onboardingFlow == .family ? 480 : 420
        case .lifeStyle:
            return coordinator.onboardingFlow == .family ? 480 : 400
        case .nutrition:
            return coordinator.onboardingFlow == .family ? 480 : 420
        case .ethical:
            return coordinator.onboardingFlow == .family ? 460 : 380
        case .taste:
            return coordinator.onboardingFlow == .family ? 460 : 380
        case .chatIntro:
            return 540
        case .chatConversation:
            return UIScreen.main.bounds.height * 0.75
        case .homeDefault:
            return 0
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
            Allergies(onboardingFlowType: getOnboardingFlowType())
            
        case .intolerances:
            Intolerances(onboardingFlowType: getOnboardingFlowType())
            
        case .healthConditions:
            HealthConditions(onboardingFlowType: getOnboardingFlowType())
            
        case .lifeStage:
            LifeStage(onboardingFlowType: getOnboardingFlowType())
            
        case .region:
            Region(onboardingFlowType: getOnboardingFlowType())
            
        case .avoid:
            Avoid(onboardingFlowType: getOnboardingFlowType())
            
        case .lifeStyle:
            LifeStyle(onboardingFlowType: getOnboardingFlowType())
            
        case .nutrition:
            Nutrition(onboardingFlowType: getOnboardingFlowType())
            
        case .ethical:
            Ethical(onboardingFlowType: getOnboardingFlowType())
            
        case .taste:
            Taste(onboardingFlowType: getOnboardingFlowType())
            
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

