import SwiftUI

@Observable class UserPreferences {
    var preferences: [String] {
        didSet {
            savePreferences()
        }
    }
    
    init() {
        preferences = UserDefaults.standard.stringArray(forKey: "userPreferences") ?? []
    }
    
    private func savePreferences() {
        UserDefaults.standard.set(preferences, forKey: "userPreferences")
    }
}
