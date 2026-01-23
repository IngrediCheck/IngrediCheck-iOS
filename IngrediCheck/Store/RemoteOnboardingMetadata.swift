//
//  RemoteOnboardingMetadata.swift
//  IngrediCheck
//
//  Created to persist onboarding state in Supabase raw_user_meta_data
//

import Foundation

/// High-level "where is the user in onboarding?" - covers all flows
enum RemoteOnboardingStage: String, Codable {
    case none
    case preOnboarding      // heyThere / blank / letsGetStarted / invite code flow
    case choosingFlow       // whosThisFor, letsMeetYourIngrediFam, etc.
    case dietaryIntro       // dietaryPreferencesAndRestrictions + dietaryPreferencesSheet
    case dynamicOnboarding  // MainCanvas + onboardingStep(stepId:)
    case fineTune           // fineTuneYourExperience
    case completed          // home / summary
}

/// Bottom sheet route identifier for serialization
enum BottomSheetRouteIdentifier: String, Codable {
    case alreadyHaveAnAccount
    case welcomeBack
    case doYouHaveAnInviteCode
    case enterInviteCode
    case whosThisFor
    case letsMeetYourIngrediFam
    case whatsYourName
    case addMoreMembers
    case addMoreMembersMinimal
    case wouldYouLikeToInvite
    case wantToAddPreference
    case generateAvatar
    case bringingYourAvatar
    case meetYourAvatar
    case yourCurrentAvatar
    case setUpAvatarFor
    case updateAvatar
    case dietaryPreferencesSheet
    case allSetToJoinYourFamily
    case onboardingStep
    case fineTuneYourExperience
    case homeDefault
    case chatIntro
    case chatConversation
    case workingOnSummary
    case editMember
    case meetYourProfileIntro
    case meetYourProfile
    case preferencesAddedSuccess
    case readyToScanFirstProduct
    case seeHowScanningWorks
    case quickAccessNeeded
    case loginToContinue
}

/// Full snapshot of onboarding position stored in raw_user_meta_data
struct RemoteOnboardingMetadata: Codable {
    var flowType: OnboardingFlowType?
    var stage: RemoteOnboardingStage?
    var currentStepId: String?    // from BottomSheetRoute.onboardingStep(stepId:)
    var bottomSheetRoute: BottomSheetRouteIdentifier?  // which bottom sheet route
    var bottomSheetRouteParam: String?  // associated value (name, isFamilyFlow as string, etc.)
}

