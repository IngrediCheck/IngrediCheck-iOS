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
    
    /// Optional callback invoked after navigation changes to sync state to Supabase
    var onNavigationChange: (() async -> Void)?

    init(initialRoute: CanvasRoute = .heyThere) {
        self.currentCanvasRoute = initialRoute
        self.currentBottomSheetRoute = AppNavigationCoordinator.bottomSheetRoute(for: initialRoute)
    }
    
    // MARK: - Local Resume Snapshot
    
    private var canvasRouteIdentifier: (id: String, param: String?) {
        switch currentCanvasRoute {
        case .heyThere:
            return ("heyThere", nil)
        case .blankScreen:
            return ("blankScreen", nil)
        case .letsGetStarted:
            return ("letsGetStarted", nil)
        case .letsMeetYourIngrediFam:
            return ("letsMeetYourIngrediFam", nil)
        case .dietaryPreferencesAndRestrictions(let isFamilyFlow):
            return ("dietaryPreferencesAndRestrictions", isFamilyFlow ? "true" : "false")
        case .welcomeToYourFamily:
            return ("welcomeToYourFamily", nil)
        case .mainCanvas(let flow):
            return ("mainCanvas", flow.rawValue)
        case .home:
            return ("home", nil)
        }
    }
    
    private static func restoreCanvasRoute(id: String, param: String?) -> CanvasRoute {
        switch id {
        case "heyThere":
            return .heyThere
        case "blankScreen":
            return .blankScreen
        case "letsGetStarted":
            return .letsGetStarted
        case "letsMeetYourIngrediFam":
            return .letsMeetYourIngrediFam
        case "dietaryPreferencesAndRestrictions":
            return .dietaryPreferencesAndRestrictions(isFamilyFlow: param == "true")
        case "welcomeToYourFamily":
            return .welcomeToYourFamily
        case "mainCanvas":
            return .mainCanvas(flow: OnboardingFlowType(rawValue: param ?? "individual") ?? .individual)
        case "home":
            return .home
        default:
            return .heyThere
        }
    }
    
    private func persistResumeSnapshot() {
        let canvas = canvasRouteIdentifier
        let sheet = bottomSheetRouteIdentifier
        let snapshot = OnboardingResumeSnapshot(
            canvasRouteId: canvas.id,
            canvasRouteParam: canvas.param,
            bottomSheetRouteId: sheet?.identifier.rawValue ?? "homeDefault",
            bottomSheetRouteParam: sheet?.param,
            savedAt: Date()
        )
        OnboardingResumeStore.save(snapshot)
    }
    
    static func restoreFromSnapshot(_ snapshot: OnboardingResumeSnapshot) -> (canvas: CanvasRoute, sheet: BottomSheetRoute) {
        let canvas = restoreCanvasRoute(id: snapshot.canvasRouteId, param: snapshot.canvasRouteParam)
        let sheetId = BottomSheetRouteIdentifier(rawValue: snapshot.bottomSheetRouteId) ?? .homeDefault
        let sheet = restoreBottomSheetRoute(from: sheetId, param: snapshot.bottomSheetRouteParam)
        return (canvas, sheet)
    }
    
    func setCanvasRoute(_ route: CanvasRoute) {
        withAnimation(.easeInOut) {
            currentCanvasRoute = route
            if case .mainCanvas(let flow) = route {
                onboardingFlow = flow
            }
            currentBottomSheetRoute = AppNavigationCoordinator.bottomSheetRoute(for: route)
        }
        
        persistResumeSnapshot()
        if case .home = route {
            OnboardingResumeStore.clear()
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
            currentBottomSheetRoute = route
        }
        persistResumeSnapshot()
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
        }
    }
    
    // MARK: - Remote Onboarding Metadata Helpers
    
    /// Derives the high-level onboarding stage from current canvas route
    var remoteOnboardingStage: RemoteOnboardingStage {
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
            
        case .home:
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
        case .wouldYouLikeToInvite(let name):
            return (.wouldYouLikeToInvite, name)
        case .wantToAddPreference(let name):
            return (.wantToAddPreference, name)
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
        case .wouldYouLikeToInvite:
            return .wouldYouLikeToInvite(name: param ?? "")
        case .wantToAddPreference:
            return .wantToAddPreference(name: param ?? "")
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
        }
    }
}
