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

enum OnboardingFlowType: String {
    case individual
    case family
}

enum OnboardingScreenId: String {
    case allergies
    case intolerances
    case healthConditions
    case lifeStage
    case region
    case aviod
    case lifeStyle
    case nutrition
    case ethical
    case taste
}

struct OnboardingScreen: Identifiable {
    var id = UUID()
    var screenId: OnboardingScreenId
    var buildView: (OnboardingFlowType, Binding<Preferences>) -> AnyView
}

struct OnboardingSection: Identifiable {
    var id = UUID()
    var name: String
    var screens: [OnboardingScreen]
    var isComplete: Bool = false
}

struct OnboardingSectionsFactory {
    static func sections() -> [OnboardingSection] {
        return [
            OnboardingSection(name: "Allergies", screens: [
                OnboardingScreen(screenId: .allergies, buildView: { flow, prefs in
                    AnyView(Allergies(onboardingFlowType: flow, preferences: prefs))
                })
            ]),
            OnboardingSection(name: "Intolerances", screens: [
                OnboardingScreen(screenId: .intolerances, buildView: { flow, prefs in
                    AnyView(Intolerances(onboardingFlowType: flow, preferences: prefs))
                })
            ]),
            OnboardingSection(name: "Health Conditions", screens: [
                OnboardingScreen(screenId: .healthConditions, buildView: { flow, prefs in
                    AnyView(HealthConditions(onboardingFlowType: flow, preferences: prefs))
                })
            ]),
            OnboardingSection(name: "Life Stage", screens: [
                OnboardingScreen(screenId: .lifeStage, buildView: { flow, prefs in
                    AnyView(LifeStage(onboardingFlowType: flow, preferences: prefs))
                })
            ]),
            OnboardingSection(name: "Region", screens: [
                OnboardingScreen(screenId: .region, buildView: { flow, prefs in
                    AnyView(Region(onboardingFlowType: flow, preferences: prefs))
                }),
//                OnboardingScreen(screenId: .region, view: AnyView(Text("Inner Region: \(onboardingFlowType.rawValue)")))
            ]),
            OnboardingSection(name: "Avoid", screens: [
                OnboardingScreen(screenId: .aviod, buildView: { flow, prefs in
                    AnyView(Avoid(onboardingFlowType: flow, preferences: prefs))
                })
            ]),
            OnboardingSection(name: "Life Style", screens: [
                OnboardingScreen(screenId: .lifeStyle, buildView: { flow, prefs in
                    AnyView(LifeStyle(onboardingFlowType: flow, preferences: prefs))
                })
            ]),
            OnboardingSection(name: "Nutrition", screens: [
                OnboardingScreen(screenId: .nutrition, buildView: { flow, prefs in
                    AnyView(Nutrition(onboardingFlowType: flow, preferences: prefs))
                })
            ]),
            OnboardingSection(name: "Ethical", screens: [
                OnboardingScreen(screenId: .ethical, buildView: { flow, prefs in
                    AnyView(Ethical(onboardingFlowType: flow, preferences: prefs))
                })
            ]),
            OnboardingSection(name: "Taste", screens: [
                OnboardingScreen(screenId: .taste, buildView: { flow, prefs in
                    AnyView(Taste(onboardingFlowType: flow, preferences: prefs))
                })
            ])
        ]
    }
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
        self.sections = steps.compactMap { step in
            guard let screenId = OnboardingScreenId(rawValue: step.id) else {
                return nil
            }
            
            let screen = OnboardingScreen(
                screenId: screenId,
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
    
    func step(for screenId: OnboardingScreenId) -> DynamicStep? {
        dynamicSteps.first { $0.id == screenId.rawValue }
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
}
