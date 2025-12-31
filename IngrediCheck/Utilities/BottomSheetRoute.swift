//
//  BottomSheetRoute.swift
//  IngrediCheckPreview
//
//  Created on 13/11/25.
//

import Foundation

enum BottomSheetRoute: Hashable {
    // HeyThereScreen routes
    case alreadyHaveAnAccount
    case welcomeBack
    
    // BlankScreen routes
    case doYouHaveAnInviteCode
    case enterInviteCode
    
    // LetsGetStartedView route
    case whosThisFor
    
    // LetsMeetYourIngrediFamView routes
    case letsMeetYourIngrediFam
    case whatsYourName
    case addMoreMembers
    case addMoreMembersMinimal
    case editMember(memberId: UUID, isSelf: Bool)
    case wouldYouLikeToInvite(memberId: UUID, name: String)
    case wantToAddPreference(name: String)
    case generateAvatar
    case bringingYourAvatar
    case meetYourAvatar
    case yourCurrentAvatar
    case setUpAvatarFor
    
    // DietaryPreferencesAndRestrictions route
    case dietaryPreferencesSheet(isFamilyFlow: Bool)
    
    // WelcomeToYourFamilyView route
    case allSetToJoinYourFamily
    
    // MainCanvasView routes (onboarding) - dynamic from JSON
    case onboardingStep(stepId: String)
    
    // FineTuneYourExperience route
    case fineTuneYourExperience
    
    // HomeView route (empty or default state)
    case homeDefault
    
    // AI ChatBot
    case chatIntro
    case chatConversation
    
    // Onboarding completion flow
    case workingOnSummary
    case meetYourProfileIntro
    case meetYourProfile
}


