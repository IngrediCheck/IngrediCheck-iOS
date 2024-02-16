import SwiftUI

enum CaptureType: String {
    case barcode = "barcode"
    case ingredients = "ingredients"
}

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
    
    private static let captureTypeKey = "config.lastUsedCaptureType"
    
    private static func readLastUsedCaptureType() -> CaptureType {
        guard let rawValue = UserDefaults.standard.string(forKey: captureTypeKey),
              let captureType = CaptureType(rawValue: rawValue) else {
            return .barcode
        }
        return captureType
    }
    
    private static func writeLastUsedCaptureType(captureType: CaptureType) {
        UserDefaults.standard.set(captureType.rawValue, forKey: captureTypeKey)
    }

    var captureType: CaptureType = UserPreferences.readLastUsedCaptureType() {
        didSet {
            UserPreferences.writeLastUsedCaptureType(captureType: captureType)
        }
    }
}
