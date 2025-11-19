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
            
            ZStack(alignment: .bottomTrailing) {
                bottomSheetContent(for: coordinator.currentBottomSheetRoute)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                if shouldShowOnboardingNextArrow {
                    Button(action: handleOnboardingNextTapped) {
                        GreenCircle()
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
                }
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
        case .homeDefault:
            return 0
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
            Allergies(onboardingFlowType: getOnboardingFlowType(), preferences: $store.preferences)
            
        case .intolerances:
            Intolerances(onboardingFlowType: getOnboardingFlowType(), preferences: $store.preferences)
            
        case .healthConditions:
            HealthConditions(onboardingFlowType: getOnboardingFlowType(), preferences: $store.preferences)
            
        case .lifeStage:
            LifeStage(onboardingFlowType: getOnboardingFlowType(), preferences: $store.preferences)
            
        case .region:
            Region(onboardingFlowType: getOnboardingFlowType(), preferences: $store.preferences)
            
        case .avoid:
            Avoid(onboardingFlowType: getOnboardingFlowType(), preferences: $store.preferences)
            
        case .lifeStyle:
            LifeStyle(onboardingFlowType: getOnboardingFlowType(), preferences: $store.preferences)
            
        case .nutrition:
            Nutrition(onboardingFlowType: getOnboardingFlowType(), preferences: $store.preferences)
            
        case .ethical:
            Ethical(onboardingFlowType: getOnboardingFlowType(), preferences: $store.preferences)
            
        case .taste:
            Taste(onboardingFlowType: getOnboardingFlowType(), preferences: $store.preferences)
            
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

