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
        self.sections = OnboardingSectionsFactory.sections()
    }
    
    var currentSection: OnboardingSection {
        sections[currentSectionIndex]
    }
    
    var currentScreen: OnboardingScreen {
        currentSection.screens[currentScreenIndex]
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
