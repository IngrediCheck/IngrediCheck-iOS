//
//  CanvasMode.swift
//  IngrediCheck
//
//  Unified canvas mode configuration for onboarding and editing contexts.
//

import Foundation

/// Defines the mode of the UnifiedCanvasView, determining which UI elements are shown.
enum CanvasMode: Equatable {
    /// Onboarding flow with progress bar and tag navigation
    case onboarding(flow: OnboardingFlowType)

    /// Editing mode from Home/Profile with edit buttons and member filtering
    case editing

    // MARK: - UI Configuration Properties

    /// Show progress bar at top (onboarding only)
    var showProgressBar: Bool {
        if case .onboarding = self { return true }
        return false
    }

    /// Show tag bar for section navigation (onboarding only)
    var showTagBar: Bool {
        if case .onboarding = self { return true }
        return false
    }

    /// Show edit buttons on each card (editing only)
    var showEditButtons: Bool {
        if case .editing = self { return true }
        return false
    }

    /// Show family member filter capsules (editing only)
    var showMemberFilter: Bool {
        if case .editing = self { return true }
        return false
    }

    /// Show all sections including empty ones (editing shows all, onboarding shows only non-empty)
    var showAllSections: Bool {
        if case .editing = self { return true }
        return false
    }

    /// Show tab bar at bottom (editing only)
    var showTabBar: Bool {
        if case .editing = self { return true }
        return false
    }

    /// Show family icons on chips
    var showFamilyIcons: Bool {
        switch self {
        case .onboarding(let flow):
            return flow == .family || flow == .singleMember
        case .editing:
            return true // Always show in editing mode (if family exists)
        }
    }

    /// Get the onboarding flow type if in onboarding mode
    var onboardingFlow: OnboardingFlowType? {
        if case .onboarding(let flow) = self {
            return flow
        }
        return nil
    }
}
