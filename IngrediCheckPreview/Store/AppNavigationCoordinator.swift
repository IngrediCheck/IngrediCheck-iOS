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
    
    init(initialRoute: CanvasRoute = .heyThere) {
        self.currentCanvasRoute = initialRoute
        self.currentBottomSheetRoute = AppNavigationCoordinator.bottomSheetRoute(for: initialRoute)
    }
    
    func setCanvasRoute(_ route: CanvasRoute) {
        withAnimation(.easeInOut) {
            currentCanvasRoute = route
            if case .mainCanvas(let flow) = route {
                onboardingFlow = flow
            }
            currentBottomSheetRoute = AppNavigationCoordinator.bottomSheetRoute(for: route)
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
    }
    
    func resetBottomSheet() {
        withAnimation(.easeInOut) {
            currentBottomSheetRoute = AppNavigationCoordinator.bottomSheetRoute(for: currentCanvasRoute)
        }
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
            return .allergies
        case .home:
            return .homeDefault
        }
    }
}
