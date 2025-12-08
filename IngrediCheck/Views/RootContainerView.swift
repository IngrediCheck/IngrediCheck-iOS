//
//  RootContainerView.swift
//  IngrediCheckPreview
//
//  Created on 13/11/25.
//

import SwiftUI

struct RootContainerView: View {
    @State private var coordinator = AppNavigationCoordinator()
    @StateObject private var onboarding = Onboarding(onboardingFlowtype: .individual)
    @State private var webService = WebService()
    @Environment(FamilyStore.self) private var familyStore
    @Environment(AuthController.self) private var authController
    
    var body: some View {
        @Bindable var coordinator = coordinator
        
        ZStack(alignment: .bottom) {
            canvasContent(for: coordinator.currentCanvasRoute)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            PersistentBottomSheet()
        }
        .environment(coordinator)
        .environmentObject(onboarding)
        .environment(webService)
        .environment(authController)
        .task {
            // Load family state when the preview container becomes active.
            await familyStore.loadCurrentFamily()
        }
    }
    
    @ViewBuilder
    private func canvasContent(for route: CanvasRoute) -> some View {
        switch route {
        case .heyThere:
            HeyThereScreen()
        case .blankScreen:
            BlankScreen()
        case .letsGetStarted:
            LetsGetStartedView()
        case .letsMeetYourIngrediFam:
            LetsMeetYourIngrediFamView()
        case .dietaryPreferencesAndRestrictions(let isFamilyFlow):
            DietaryPreferencesAndRestrictions(isFamilyFlow: isFamilyFlow)
        case .welcomeToYourFamily:
            WelcomeToYourFamilyView()
        case .mainCanvas(let flow):
            MainCanvasView(flow: flow)
        case .home:
            HomeView()
        }
    }
}

