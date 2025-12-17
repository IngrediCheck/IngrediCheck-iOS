//
//  OnboardingResumeStore.swift
//  IngrediCheck
//
//  Local-only resume snapshot for preview onboarding flow.
//

import Foundation

struct OnboardingResumeSnapshot: Codable {
    var canvasRouteId: String
    var canvasRouteParam: String?
    var bottomSheetRouteId: String
    var bottomSheetRouteParam: String?
    var savedAt: Date
}

enum OnboardingResumeStore {
    private static let key = "onboardingResumeSnapshot.v1"

    static func save(_ snapshot: OnboardingResumeSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> OnboardingResumeSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(OnboardingResumeSnapshot.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}


