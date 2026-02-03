//
//  AppNavigationCoordinator.swift
//  IngrediCheckPreview
//
//  Created on 13/11/25.
//

import SwiftUI
import Observation

/**
 # AppNavigationCoordinator
 
 A single source of truth that keeps the large “canvas” presentation
 (Splash → Onboarding → Home) and the persistent bottom sheet in sync.
 The coordinator is created once in `RootContainerView`, injected via
 Swift Observation’s `.environment(_:)`, and every view reads or mutates
 shared navigation state through that instance.
 
 ## Responsibilities
 - Tracks the current canvas route (`currentCanvasRoute`).
 - Resolves and exposes the matching bottom sheet (`currentBottomSheetRoute`).
 - Stores the active onboarding flow so sheet sizing/content can react.
 - Provides `setCanvasRoute`, `showCanvas`, `navigateInBottomSheet`, and
   reset helpers, each wrapped in `withAnimation(.easeInOut)` to give the
   default Apple transition between destinations.
 
 ## Usage
 ```swift
 struct RootContainerView: View {
     @State private var coordinator = AppNavigationCoordinator()
     
     var body: some View {
         @Bindable var coordinator = coordinator
         
         ZStack(alignment: .bottom) {
             canvasContent(for: coordinator.currentCanvasRoute)
             PersistentBottomSheet()
         }
         .environment(coordinator) // makes coordinator available via @Environment
     }
 }
 
 struct HeyThereScreen: View {
     @Environment(AppNavigationCoordinator.self) private var coordinator
     
     var body: some View {
         Button("Get Started") {
             coordinator.showCanvas(.blankScreen)
         }
     }
 }
 ```
 */
@Observable
@MainActor
class AppNavigationCoordinator {
    private(set) var currentCanvasRoute: CanvasRoute
    private(set) var currentBottomSheetRoute: BottomSheetRoute
    private(set) var onboardingFlow: OnboardingFlowType = .individual
    private var previousBottomSheetRoute: BottomSheetRoute?
    // Track if family creation was initiated from Settings
    var isCreatingFamilyFromSettings: Bool = false

    // Track if user just joined a family via invite code
    var isJoiningViaInviteCode: Bool = false

    // Track if we're in "add preferences for member" flow
    var isAddingPreferencesForMember: Bool = false
    var addPreferencesForMemberId: UUID? = nil
    var addPreferencesOriginIsSettings: Bool = false  // True if started from Settings → Manage Family
    
    // Global state for secondary edit sheet
    var editingStepId: String? = nil
    var isEditSheetPresented: Bool = false
    var currentEditingSectionIndex: Int = 0
    var editingMemberId: UUID? = nil  // Track which member is being edited

    // Global state for AI Bot sheet (post-login)
    var isAIBotSheetPresented: Bool = false

    // MARK: - AIBot Context Properties
    var aibotContextScanId: String? = nil
    var aibotContextAnalysisId: String? = nil
    var aibotContextIngredientName: String? = nil
    var aibotContextFeedbackId: String? = nil
    var aibotContextScreenOverride: String? = nil  // Explicit screen context (e.g., "food_notes")

    // MARK: - Feedback Prompt Bubble State
    var showFeedbackPromptBubble: Bool = false
    var pendingFeedbackId: String? = nil

    /// Optional callback invoked after navigation changes to sync state to Supabase
    var onNavigationChange: (() async -> Void)?

    init(initialRoute: CanvasRoute = .heyThere) {
        // PRIORITY: Check local persistence first.
        // If the user has completed onboarding previously, FORCE start at .home
        // regardless of what the caller passed (unless we want to support deep linking to specific onboarding steps, 
        // but for app launch .heyThere is usually passed).
        if OnboardingPersistence.shared.isLocallyCompleted {
            self.currentCanvasRoute = .home
            self.onboardingFlow = .individual // Default, will be updated if needed or doesn't matter for Home
            self.currentBottomSheetRoute = .homeDefault
        } else {
            self.currentCanvasRoute = initialRoute
            if case .mainCanvas(let flow) = initialRoute {
                self.onboardingFlow = flow
            }
            self.currentBottomSheetRoute = AppNavigationCoordinator.bottomSheetRoute(for: initialRoute)
        }
    }
    
    func setCanvasRoute(_ route: CanvasRoute) {
        withAnimation(.easeInOut) {
            currentCanvasRoute = route
            
            // Explicitly update onboardingFlow based on the route
            switch route {
            case .mainCanvas(let flow):
                onboardingFlow = flow
            case .letsMeetYourIngrediFam, .welcomeToYourFamily:
                onboardingFlow = .family
            case .dietaryPreferencesAndRestrictions(let isFamilyFlow):
                onboardingFlow = isFamilyFlow ? .family : .individual
            default:
                break
            }
            
            currentBottomSheetRoute = AppNavigationCoordinator.bottomSheetRoute(for: route)
        }
        
        // Sync to Supabase after navigation change
        Task {
            await onNavigationChange?()
        }
    }
    
    func showCanvas(_ route: CanvasRoute) {
        setCanvasRoute(route)
    }
    
    // Navigate bottom sheet
    func navigateInBottomSheet(_ route: BottomSheetRoute) {
        withAnimation(.easeInOut) {
            // When navigating back to the early onboarding sheets that live on the HeyThere canvas,
            // ensure the canvas is reset to .heyThere so the correct background imagery shows.
            // BUT: Only do this if onboarding is NOT completed, otherwise we'll reset users back to Get Started screen
            switch route {
            case .alreadyHaveAnAccount, .welcomeBack, .doYouHaveAnInviteCode, .enterInviteCode, .whosThisFor:
                // Only reset to .heyThere if onboarding is not completed
                if !OnboardingPersistence.shared.isLocallyCompleted && currentCanvasRoute != .heyThere {
                    currentCanvasRoute = .heyThere
                }
            default:
                break
            }
            currentBottomSheetRoute = route
        }
        // Sync to Supabase after navigation change
        Task {
            await onNavigationChange?()
        }
    }
    
    func resetBottomSheet() {
        withAnimation(.easeInOut) {
            currentBottomSheetRoute = AppNavigationCoordinator.bottomSheetRoute(for: currentCanvasRoute)
        }
    }
    
    // MARK: - ChatBot Presentation
    private var isChatRoute: Bool {
        switch currentBottomSheetRoute {
        case .chatIntro, .chatConversation:
            return true
        default:
            return false
        }
    }
    
    func presentChatBot(startAtConversation: Bool = false) {
        if !isChatRoute {
            previousBottomSheetRoute = currentBottomSheetRoute
        }
        
        withAnimation(.easeInOut) {
            currentBottomSheetRoute = startAtConversation ? .chatConversation : .chatIntro
        }
    }
    
    func showChatConversation() {
        withAnimation(.easeInOut) {
            currentBottomSheetRoute = .chatConversation
        }
    }
    
    func dismissChatBot() {
        withAnimation(.easeInOut) {
            if let previous = previousBottomSheetRoute {
                currentBottomSheetRoute = previous
            } else {
                currentBottomSheetRoute = AppNavigationCoordinator.bottomSheetRoute(for: currentCanvasRoute)
            }
        }
        previousBottomSheetRoute = nil
    }

    // MARK: - Global AI Bot Sheet (Post-Login)

    func showAIBotSheet() {
        isAIBotSheetPresented = true
    }

    func showAIBotSheetWithContext(
        scanId: String? = nil,
        analysisId: String? = nil,
        ingredientName: String? = nil,
        feedbackId: String? = nil,
        screenOverride: String? = nil
    ) {
        aibotContextScanId = scanId
        aibotContextAnalysisId = analysisId
        aibotContextIngredientName = ingredientName
        aibotContextFeedbackId = feedbackId
        aibotContextScreenOverride = screenOverride
        isAIBotSheetPresented = true
    }

    func dismissAIBotSheet() {
        isAIBotSheetPresented = false
        aibotContextScanId = nil
        aibotContextAnalysisId = nil
        aibotContextIngredientName = nil
        aibotContextFeedbackId = nil
        aibotContextScreenOverride = nil
    }

    // MARK: - Feedback Prompt Bubble

    func showFeedbackPrompt(feedbackId: String) {
        pendingFeedbackId = feedbackId
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showFeedbackPromptBubble = true
        }
    }

    func dismissFeedbackPrompt(openChat: Bool = false) {
        if openChat, let feedbackId = pendingFeedbackId {
            showAIBotSheetWithContext(feedbackId: feedbackId)
        }
        withAnimation {
            showFeedbackPromptBubble = false
        }
        pendingFeedbackId = nil
    }

    // Get bottom sheet route for current canvas route
    private static func bottomSheetRoute(for canvasRoute: CanvasRoute) -> BottomSheetRoute {
        switch canvasRoute {
        case .heyThere:
            return .alreadyHaveAnAccount
        case .blankScreen:
            return .doYouHaveAnInviteCode
        case .letsGetStarted:
            return .whosThisFor
        case .letsMeetYourIngrediFam:
            return .letsMeetYourIngrediFam
        case .dietaryPreferencesAndRestrictions(let isFamilyFlow):
            return .dietaryPreferencesSheet(isFamilyFlow: isFamilyFlow)
        case .welcomeToYourFamily:
            return .allSetToJoinYourFamily
        case .mainCanvas:
            // Get first step ID from JSON dynamically
            let steps = DynamicStepsProvider.loadSteps()
            if let firstStepId = steps.first?.id {
                return .onboardingStep(stepId: firstStepId)
            }
            // Fallback (should not happen if JSON is valid)
            return .homeDefault
        case .home:
            return .homeDefault
        case .summaryJustMe:
            return .preferencesAddedSuccess
        case .summaryAddFamily:
            return .allSetToJoinYourFamily
        case .readyToScanFirstProduct:
            return .readyToScanFirstProduct
        case .seeHowScanningWorks:
            return .seeHowScanningWorks
        case .whyWeNeedThesePermissions:
            return .quickAccessNeeded
        }
    }
    
    // MARK: - Remote Onboarding Metadata Helpers
    
    /// Derives the high-level onboarding stage from current canvas route and bottom sheet
    var remoteOnboardingStage: RemoteOnboardingStage {
        // Check bottom sheet first for more specific stage detection
        switch currentBottomSheetRoute {
        case .whosThisFor:
            // whosThisFor is part of choosing flow, even though canvas might be .heyThere
            return .choosingFlow
        case .letsMeetYourIngrediFam, .whatsYourName, .addMoreMembers, .addMoreMembersMinimal:
            return .choosingFlow
        default:
            break
        }
        
        // Fall back to canvas route-based stage
        switch currentCanvasRoute {
        case .heyThere, .blankScreen, .letsGetStarted:
            return .preOnboarding
            
        case .letsMeetYourIngrediFam, .welcomeToYourFamily:
            return .choosingFlow
            
        case .dietaryPreferencesAndRestrictions:
            return .dietaryIntro
            
        case .mainCanvas:
            // Check if we're on fineTuneYourExperience bottom sheet
            if case .fineTuneYourExperience = currentBottomSheetRoute {
                return .fineTune
            }
            return .dynamicOnboarding
            
        case .home, .summaryJustMe, .summaryAddFamily, .readyToScanFirstProduct, .seeHowScanningWorks, .whyWeNeedThesePermissions:
            return .completed
        }
    }
    
    /// Extracts the current onboarding step ID from bottom sheet route, if available
    var currentOnboardingStepId: String? {
        if case .onboardingStep(let stepId) = currentBottomSheetRoute {
            return stepId
        }
        return nil
    }
    
    /// Converts current bottom sheet route to identifier + param for serialization
    var bottomSheetRouteIdentifier: (identifier: BottomSheetRouteIdentifier, param: String?)? {
        switch currentBottomSheetRoute {
        case .alreadyHaveAnAccount:
            return (.alreadyHaveAnAccount, nil)
        case .welcomeBack:
            return (.welcomeBack, nil)
        case .doYouHaveAnInviteCode:
            return (.doYouHaveAnInviteCode, nil)
        case .enterInviteCode:
            return (.enterInviteCode, nil)
        case .whosThisFor:
            return (.whosThisFor, nil)
        case .letsMeetYourIngrediFam:
            return (.letsMeetYourIngrediFam, nil)
        case .whatsYourName:
            return (.whatsYourName, nil)
        case .addMoreMembers:
            return (.addMoreMembers, nil)
        case .addMoreMembersMinimal:
            return (.addMoreMembersMinimal, nil)
        case .editMember(let memberId, let isSelf):
            return (.editMember, "\(memberId.uuidString)|\(isSelf)")
        case .wouldYouLikeToInvite(let memberId, let name):
            return (.wouldYouLikeToInvite, "\(memberId.uuidString)|\(name)")
        case .addPreferencesForMember(let memberId, let name):
            return (.addPreferencesForMember, "\(memberId.uuidString)|\(name)")
        case .generateAvatar:
            return (.generateAvatar, nil)
        case .bringingYourAvatar:
            return (.bringingYourAvatar, nil)
        case .meetYourAvatar:
            return (.meetYourAvatar, nil)
        case .yourCurrentAvatar:
            return (.yourCurrentAvatar, nil)
        case .setUpAvatarFor:
            return (.setUpAvatarFor, nil)
        case .dietaryPreferencesSheet(let isFamilyFlow):
            return (.dietaryPreferencesSheet, isFamilyFlow ? "true" : "false")
        case .allSetToJoinYourFamily:
            return (.allSetToJoinYourFamily, nil)
        case .onboardingStep(let stepId):
            return (.onboardingStep, stepId)
        case .fineTuneYourExperience:
            return (.fineTuneYourExperience, nil)
        case .homeDefault:
            return (.homeDefault, nil)
        case .chatIntro:
            return (.chatIntro, nil)
        case .chatConversation:
            return (.chatConversation, nil)
        case .workingOnSummary:
            return (.workingOnSummary, nil)
        case .meetYourProfileIntro:
            return (.meetYourProfileIntro, nil)
        case .meetYourProfile(let memberId):
            if let memberId = memberId {
                return (.meetYourProfile, memberId.uuidString)
            }
            return (.meetYourProfile, nil)
        case .preferencesAddedSuccess:
            return (.preferencesAddedSuccess, nil)
        case .readyToScanFirstProduct:
            return (.readyToScanFirstProduct, nil)
        case .seeHowScanningWorks:
            return (.seeHowScanningWorks, nil)
        case .quickAccessNeeded:
            return (.quickAccessNeeded, nil)
        case .loginToContinue:
            return (.loginToContinue, nil)
        case .updateAvatar(memberId: let memberId):
            return (.updateAvatar, nil)
        }
    }
    
    /// Builds the metadata snapshot for persistence
    func buildOnboardingMetadata() -> RemoteOnboardingMetadata {
        let (routeId, routeParam) = bottomSheetRouteIdentifier ?? (nil, nil)
        return RemoteOnboardingMetadata(
            flowType: onboardingFlow,
            stage: remoteOnboardingStage,
            currentStepId: currentOnboardingStepId,
            bottomSheetRoute: routeId,
            bottomSheetRouteParam: routeParam
        )
    }
    
    /// Reconstructs BottomSheetRoute from identifier + param
    static func restoreBottomSheetRoute(from identifier: BottomSheetRouteIdentifier, param: String?) -> BottomSheetRoute {
        switch identifier {
        case .alreadyHaveAnAccount:
            return .alreadyHaveAnAccount
        case .welcomeBack:
            return .welcomeBack
        case .doYouHaveAnInviteCode:
            return .doYouHaveAnInviteCode
        case .enterInviteCode:
            return .enterInviteCode
        case .whosThisFor:
            return .whosThisFor
        case .letsMeetYourIngrediFam:
            return .letsMeetYourIngrediFam
        case .whatsYourName:
            return .whatsYourName
        case .addMoreMembers:
            return .addMoreMembers
        case .addMoreMembersMinimal:
            return .addMoreMembersMinimal
        case .editMember:
             let parts = (param ?? "").split(separator: "|")
             if parts.count >= 2, let id = UUID(uuidString: String(parts[0])), let isSelf = Bool(String(parts[1])) {
                  return .editMember(memberId: id, isSelf: isSelf)
             }
             return .homeDefault
        case .wouldYouLikeToInvite:
            let parts = (param ?? "").split(separator: "|")
            if parts.count >= 2, let id = UUID(uuidString: String(parts[0])) {
                let name = String(parts[1])
                return .wouldYouLikeToInvite(memberId: id, name: name)
            }
            return .homeDefault
        case .addPreferencesForMember:
            let parts = (param ?? "").split(separator: "|")
            if parts.count >= 2, let id = UUID(uuidString: String(parts[0])) {
                let name = String(parts[1])
                return .addPreferencesForMember(memberId: id, name: name)
            }
            return .homeDefault
        case .generateAvatar:
            return .generateAvatar
        case .bringingYourAvatar:
            return .bringingYourAvatar
        case .meetYourAvatar:
            return .meetYourAvatar
        case .yourCurrentAvatar:
            return .yourCurrentAvatar
        case .setUpAvatarFor:
            return .setUpAvatarFor
        case .dietaryPreferencesSheet:
            let isFamilyFlow = param == "true"
            return .dietaryPreferencesSheet(isFamilyFlow: isFamilyFlow)
        case .allSetToJoinYourFamily:
            return .allSetToJoinYourFamily
        case .onboardingStep:
            return .onboardingStep(stepId: param ?? "")
        case .fineTuneYourExperience:
            return .fineTuneYourExperience
        case .homeDefault:
            return .homeDefault
        case .chatIntro:
            return .chatIntro
        case .chatConversation:
            return .chatConversation
        case .workingOnSummary:
            return .workingOnSummary
        case .meetYourProfileIntro:
            return .meetYourProfileIntro
        case .meetYourProfile:
            if let param = param, let memberId = UUID(uuidString: param) {
                return .meetYourProfile(memberId: memberId)
            }
            return .meetYourProfile(memberId: nil)
        case .preferencesAddedSuccess:
            return .preferencesAddedSuccess
        case .readyToScanFirstProduct:
            return .readyToScanFirstProduct
        case .seeHowScanningWorks:
            return .seeHowScanningWorks
        case .quickAccessNeeded:
            return .quickAccessNeeded
        case .loginToContinue:
            return .loginToContinue
        case .updateAvatar:
            return .generateAvatar
        }
    }
    static func restoreState(from metadata: RemoteOnboardingMetadata) -> (canvas: CanvasRoute, sheet: BottomSheetRoute) {
        // 1. Restore Sheet
        let sheetId = metadata.bottomSheetRoute ?? .homeDefault
        let sheet = restoreBottomSheetRoute(from: sheetId, param: metadata.bottomSheetRouteParam)

        // 2. Restore Canvas based on Stage + Flow
        var canvas: CanvasRoute
        let flow = metadata.flowType ?? .individual
        
        switch metadata.stage ?? .none {
        case .none, .preOnboarding:
            canvas = .heyThere
        case .choosingFlow:
            canvas = .letsMeetYourIngrediFam
        case .dietaryIntro:
            canvas = .dietaryPreferencesAndRestrictions(isFamilyFlow: flow == .family)
        case .dynamicOnboarding:
            canvas = .mainCanvas(flow: flow)
        case .fineTune:
            canvas = .mainCanvas(flow: flow)
        case .completed:
            // summaryJustMe uses .completed stage too, but we distinguish by sheet
            canvas = .home
        }

        // 3. Refine Canvas based on specific Sheets that map to specific Canvases
        // This overrides the broader 'stage' based guess for accuracy
        switch sheet {
        case .alreadyHaveAnAccount, .welcomeBack, .doYouHaveAnInviteCode, .enterInviteCode, .whosThisFor:
             // These sheets all appear on .heyThere canvas (consistent with navigateInBottomSheet logic)
             canvas = .heyThere
        case .letsMeetYourIngrediFam, .whatsYourName, .addMoreMembers, .addMoreMembersMinimal, .editMember, .wouldYouLikeToInvite, .addPreferencesForMember, .generateAvatar, .bringingYourAvatar, .meetYourAvatar, .yourCurrentAvatar, .setUpAvatarFor:
             canvas = .letsMeetYourIngrediFam
        case .dietaryPreferencesSheet:
             // handled by stage .dietaryIntro usually, but enforce correct canvas
             canvas = .dietaryPreferencesAndRestrictions(isFamilyFlow: flow == .family)
        case .allSetToJoinYourFamily:
             canvas = .summaryAddFamily
        case .onboardingStep:
             canvas = .mainCanvas(flow: flow)
        case .fineTuneYourExperience:
             canvas = .mainCanvas(flow: flow)
        case .chatIntro, .chatConversation:
             // Chat can be presented anywhere, usually preserves background. 
             // If we are restoring fresh, we might not know background. 
             // Defaulting to home or based on stage is safe.
             break 
        case .meetYourProfile:
             canvas = .home
        case .preferencesAddedSuccess:
             canvas = .summaryJustMe
        case .readyToScanFirstProduct:
             canvas = .readyToScanFirstProduct
        case .seeHowScanningWorks:
             canvas = .seeHowScanningWorks
        case .quickAccessNeeded:
             canvas = .whyWeNeedThesePermissions
        case .loginToContinue:
             canvas = .whyWeNeedThesePermissions
        default:
             break
        }

        return (canvas, sheet)
    }
}
