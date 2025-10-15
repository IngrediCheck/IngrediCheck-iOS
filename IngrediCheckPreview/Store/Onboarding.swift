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
    var icon: String
}

struct SectionedChipModel: Identifiable {
    var id = UUID().uuidString
    var title: String
    var chips: [ChipsModel]
}

struct UserModel: Identifiable {
    var id = UUID().uuidString
    var name: String
    var image: String
    var backgroundColor: Color?
    var allergies: [String] = []
    var intolerances: [String] = []
    var healthConditions: [String] = []
    var lifeStage: [String] = []
    var region: [String] = []
    var avoid: [String] = []
    var lifestyle: [String] = []
    var nutrition: [String] = []
    var ethical: [String] = []
    var taste: [String] = []
    
    init(id: String = UUID().uuidString, familyMemberName: String, familyMemberImage: String, backgroundColor: Color? = nil) {
        self.id = id
        self.name = familyMemberName
        self.image = familyMemberImage
        self.backgroundColor = backgroundColor
    }
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
    var view: AnyView
}

struct OnboardingSection: Identifiable {
    var id = UUID()
    var name: String
    var screens: [OnboardingScreen]
    var isComplete: Bool = false
}

struct OnboardingSectionsFactory {
    static func sections(onboardingFlowType: OnboardingFlowType) -> [OnboardingSection] {
        return [
            OnboardingSection(name: "Allergies", screens: [
                OnboardingScreen(screenId: .allergies, view: AnyView(Text("Allergies: \(onboardingFlowType.rawValue)")))
            ]),
            OnboardingSection(name: "Intolerances", screens: [
                OnboardingScreen(screenId: .intolerances, view: AnyView(Text("Intolerances: \(onboardingFlowType.rawValue)")))
            ]),
            OnboardingSection(name: "Health Conditions", screens: [
                OnboardingScreen(screenId: .healthConditions, view: AnyView(Text("Health Conditions: \(onboardingFlowType.rawValue)")))
            ]),
            OnboardingSection(name: "Life stage", screens: [
                OnboardingScreen(screenId: .lifeStage, view: AnyView(Text("Life Stage: \(onboardingFlowType.rawValue)")))
            ]),
            OnboardingSection(name: "Region", screens: [
                OnboardingScreen(screenId: .region, view: AnyView(Text("Region: \(onboardingFlowType.rawValue)"))),
                OnboardingScreen(screenId: .region, view: AnyView(Text("Inner Region: \(onboardingFlowType.rawValue)")))
            ]),
            OnboardingSection(name: "Avoid", screens: [
                OnboardingScreen(screenId: .aviod, view: AnyView(Text("Avoid: \(onboardingFlowType.rawValue)")))
            ]),
            OnboardingSection(name: "Life Style", screens: [
                OnboardingScreen(screenId: .lifeStyle, view: AnyView(Text("Life Style: \(onboardingFlowType.rawValue)")))
            ]),
            OnboardingSection(name: "Nutrition", screens: [
                OnboardingScreen(screenId: .nutrition, view: AnyView(Text("Nutrition: \(onboardingFlowType.rawValue)")))
            ]),
            OnboardingSection(name: "Ethical", screens: [
                OnboardingScreen(screenId: .ethical, view: AnyView(Text("Ethical: \(onboardingFlowType.rawValue)")))
            ]),
            OnboardingSection(name: "Taste", screens: [
                OnboardingScreen(screenId: .taste, view: AnyView(Text("Taste: \(onboardingFlowType.rawValue)")))
            ])
        ]
    }
}


class Onboarding: ObservableObject {
    @Published var isOnboardingCompleted: Bool = false
    @Published var onboardingFlowtype: OnboardingFlowType = .individual
    @Published var sections: [OnboardingSection] = []
    @Published var currentSectionIndex: Int = 0
    @Published var currentScreenIndex: Int = 0
    @Published var isUploading: Bool = false
    @Published var uploadError: String?

    
    var progress: Double {
        guard !sections.isEmpty else { return 0 }
        let complete = sections.filter{ $0.isComplete }.count
        return Double(complete) / Double(sections.count)
    }
    
    init(
        onboardingFlowtype: OnboardingFlowType,
    ) {
        self.onboardingFlowtype = onboardingFlowtype
        self.sections = OnboardingSectionsFactory.sections(onboardingFlowType: onboardingFlowtype)
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
            sections[currentSectionIndex].isComplete = true
            if currentSectionIndex < sections.count - 1 {
                currentSectionIndex += 1
                currentScreenIndex = 0
            }
        }
    }
}
