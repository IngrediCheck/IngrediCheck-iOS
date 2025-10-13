import SwiftUI
import Foundation

@Observable class OnboardingState {

    struct OnboardingData: Codable {
        var version: Float
        var useCasesShown: Bool
        var disclaimerShown: Bool
    }

    private static let currentVersion: Float = 1.0
    private static let userDefaultsKey = "onboardingData"

    private static func readOnboardingData() -> OnboardingData {
        guard let rawValue = UserDefaults.standard.data(forKey: OnboardingState.userDefaultsKey),
              let data = try? JSONDecoder().decode(OnboardingData.self, from: rawValue) else {
            return OnboardingData(
                version: OnboardingState.currentVersion,
                useCasesShown: false,
                disclaimerShown: false
            )
        }
        print("On Start OnboardingState: \(data)")
        return data
    }

    private static func writeOnboardingData(_ data: OnboardingData) {
        let rawData = (try? JSONEncoder().encode(data)) ?? Data()
        UserDefaults.standard.set(rawData, forKey: OnboardingState.userDefaultsKey)
    }

    private var data: OnboardingData = OnboardingState.readOnboardingData() {
        didSet {
            OnboardingState.writeOnboardingData(data)
        }
    }

    var version: Float {
        get {
            data.version
        }
        set {
            data.version = newValue
        }
    }

    var useCasesShown: Bool {
        get {
            data.useCasesShown
        }
        set {
            data.useCasesShown = newValue
        }
    }
    
    var disclaimerShown: Bool {
        get {
            data.disclaimerShown
        }
        set {
            data.disclaimerShown = newValue
        }
    }
    
    @MainActor public func clearAll() {
        UserDefaults.standard.removeObject(forKey: OnboardingState.userDefaultsKey)
        data = OnboardingData(
            version: OnboardingState.currentVersion,
            useCasesShown: false,
            disclaimerShown: false
        )
    }
}
