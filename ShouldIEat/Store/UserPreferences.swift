import SwiftUI

@Observable class UserPreferences {
    var preferences: [String] {
        didSet {
            savePreferences()
        }
    }
    
    var asString: String {
        preferences.joined(separator: "\n")
    }
    
    init() {
        preferences = UserDefaults.standard.stringArray(forKey: "userPreferences") ?? []
    }
    
    private func savePreferences() {
        UserDefaults.standard.set(preferences, forKey: "userPreferences")
    }
}
