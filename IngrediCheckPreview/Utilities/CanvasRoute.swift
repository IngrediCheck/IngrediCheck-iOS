//
//  CanvasRoute.swift
//  IngrediCheckPreview
//
//  Created on 13/11/25.
//

import Foundation

enum CanvasRoute: Hashable {
    case heyThere
    case blankScreen
    case letsGetStarted
    case letsMeetYourIngrediFam
    case dietaryPreferencesAndRestrictions(isFamilyFlow: Bool)
    case welcomeToYourFamily
    case mainCanvas(flow: OnboardingFlowType)
    case home
    case productDetail
}


