//
//  OnboardingModel.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 14/10/25.
//

import Foundation
import SwiftUI
import Combine


struct ChipsModel: Identifiable, Equatable {
    let id = UUID().uuidString
    var name: String
    var icon: String?
}

struct SectionedChipModel: Identifiable {
    var id = UUID().uuidString
    var title: String
    var subtitle: String?
    var chips: [ChipsModel]
}

enum OnboardingFlowType: String, Codable {
    case individual
    case family
    case singleMember  // For adding a specific family member from home
}

enum OnboardingScreenId: String {
    case allergies
    case intolerances
    case healthConditions
    case lifeStage
    case region
    case avoid
    case lifeStyle
    case nutrition
    case ethical
    case taste
}

struct OnboardingScreen: Identifiable {
    var id = UUID()
    var stepId: String  // Use step ID from JSON instead of enum
    var buildView: (OnboardingFlowType, Binding<Preferences>) -> AnyView
}

struct OnboardingSection: Identifiable {
    var id = UUID()
    var name: String
    var screens: [OnboardingScreen]
    var isComplete: Bool = false
}

@MainActor
class Onboarding: ObservableObject {
    @Published var isOnboardingCompleted: Bool = false
    @Published var onboardingFlowtype: OnboardingFlowType = .individual
    @Published var sections: [OnboardingSection] = []
    /// Dynamic step configuration loaded from `dynamicJsonData.json`. Used as
    /// the single source of truth for ordering / titles / icons.
    @Published var dynamicSteps: [DynamicStep] = []
    @Published var currentSectionIndex: Int = 0
    @Published var currentScreenIndex: Int = 0
    @Published var isUploading: Bool = false
    @Published var uploadError: String?
    @Published var preferences: Preferences = Preferences()

    
    var progress: Double {
        guard !sections.isEmpty else { return 0 }
        let complete = sections.filter{ $0.isComplete }.count
        return Double(complete) / Double(sections.count)
    }
    
    init(
        onboardingFlowtype: OnboardingFlowType,
    ) {
        self.onboardingFlowtype = onboardingFlowtype
        
        // Load dynamic steps from JSON and derive sections from them so that
        // tag bar, progress, and canvas summary always stay in sync with the
        // configuration file instead of hard-coded arrays.
        let steps = DynamicStepsProvider.loadSteps()
        self.dynamicSteps = steps
        self.sections = steps.map { step in
            let screen = OnboardingScreen(
                stepId: step.id,  // Use step ID directly from JSON
                // The legacy `buildView` is no longer used for rendering – the
                // bottom sheet now drives UI via `DynamicOnboardingStepView`.
                // We keep this closure only so existing code remains compile-safe.
                buildView: { _, _ in AnyView(EmptyView()) }
            )
            
            return OnboardingSection(
                name: step.header.name,
                screens: [screen]
            )
        }
    }
    
    var currentSection: OnboardingSection {
        sections[currentSectionIndex]
    }
    
    var currentScreen: OnboardingScreen {
        currentSection.screens[currentScreenIndex]
    }
    
    // MARK: - Dynamic steps helpers
    
    /// Get step by step ID (from JSON)
    func step(for stepId: String) -> DynamicStep? {
        dynamicSteps.first { $0.id == stepId }
    }
    
    /// Get step by index
    func step(at index: Int) -> DynamicStep? {
        guard dynamicSteps.indices.contains(index) else { return nil }
        return dynamicSteps[index]
    }
    
    /// Get current step
    var currentStep: DynamicStep? {
        guard dynamicSteps.indices.contains(currentSectionIndex) else { return nil }
        return dynamicSteps[currentSectionIndex]
    }
    
    /// Get current step ID
    var currentStepId: String? {
        currentStep?.id
    }
    
    /// Get next step ID (returns nil if at last step)
    var nextStepId: String? {
        guard currentSectionIndex < dynamicSteps.count - 1 else { return nil }
        return dynamicSteps[currentSectionIndex + 1].id
    }
    
    /// Check if current step is the last one
    var isLastStep: Bool {
        currentSectionIndex >= dynamicSteps.count - 1
    }
    
    /// Get first step ID
    var firstStepId: String? {
        dynamicSteps.first?.id
    }
    
    func next() {
        // this func will have upload logic to supabase.
        moveToNextStep()
    }
    
    func moveToNextStep() {
        if currentScreenIndex < currentSection.screens.count - 1 {
            currentScreenIndex += 1
        } else {
            var section = sections[currentSectionIndex]
            section.isComplete = true
            sections[currentSectionIndex] = section
            if currentSectionIndex < sections.count - 1 {
                currentSectionIndex += 1
                currentScreenIndex = 0
            }
        }
    }
    
    /// Reset onboarding state to start from the beginning
    func reset(flowType: OnboardingFlowType) {
        onboardingFlowtype = flowType
        currentSectionIndex = 0
        currentScreenIndex = 0
        preferences = Preferences()
        isOnboardingCompleted = false
        
        // Reset all sections to incomplete
        sections = sections.map { section in
            var updatedSection = section
            updatedSection.isComplete = false
            return updatedSection
        }
    }
    
    /// Update section completion status based on whether they have data in preferences
    func updateSectionCompletionStatus() {
        for (index, section) in sections.enumerated() {
            guard let stepId = section.screens.first?.stepId,
                  let step = step(for: stepId) else { continue }
            
            let sectionName = step.header.name
            
            // Check if section has data in preferences
            var hasData = false
            if let value = preferences.sections[sectionName] {
                switch value {
                case .list(let items):
                    hasData = !items.isEmpty
                case .nested(let nestedDict):
                    // Check if any nested section has data
                    hasData = nestedDict.values.contains { !$0.isEmpty }
                }
            }
            
            // Update completion status if it differs
            if sections[index].isComplete != hasData {
                var updatedSection = sections[index]
                updatedSection.isComplete = hasData
                sections[index] = updatedSection
            }
        }
    }
    func restoreState(forStepId stepId: String) {
        guard let stepIndex = dynamicSteps.firstIndex(where: { $0.id == stepId }) else { return }
        
        // Find which section this step belongs to
        var accumulatedSteps = 0
        for (secIndex, section) in sections.enumerated() {
            let screenCount = section.screens.count
            if stepIndex < accumulatedSteps + screenCount {
                // Found the section
                currentSectionIndex = secIndex
                currentScreenIndex = stepIndex - accumulatedSteps
                return
            }
            accumulatedSteps += screenCount
        }
    }
    
    /// Set state to the very last step (used for restoration when user is at Fine Tune or Summary)
    func restoreToLastStep() {
        if !sections.isEmpty {
            currentSectionIndex = sections.count - 1
            if let lastSection = sections.last, !lastSection.screens.isEmpty {
                currentScreenIndex = lastSection.screens.count - 1
            }
        }
    }
}
