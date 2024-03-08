import SwiftUI

enum CaptureType: String {
    case barcode = "barcode"
    case ingredients = "ingredients"
}

enum HistoryType: String {
    case scans = "scans"
    case favorites = "favorites"
}

enum OcrModel: String {
    case iOSBuiltIn = "iosbuiltin"
    case googleMLKit = "googlemlkit"
}

@Observable class UserPreferences {
    @MainActor var preferences: [String] {
        didSet {
            savePreferences()
        }
    }
    
    @MainActor var asString: String {
        preferences.joined(separator: "\n")
    }
    
    @MainActor init() {
        preferences = UserDefaults.standard.stringArray(forKey: "userPreferences") ?? []
    }
    
    @MainActor private func savePreferences() {
        UserDefaults.standard.set(preferences, forKey: "userPreferences")
    }
    
    // Capture Type
    
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
    
    // History Type
    
    private static let historyTypeKey = "config.historyType"
    
    private static func readLastUsedHistoryType() -> HistoryType {
        guard let rawValue = UserDefaults.standard.string(forKey: historyTypeKey),
              let historyType = HistoryType(rawValue: rawValue) else {
            return .scans
        }
        return historyType
    }
    
    private static func writeLastUsedHistoryType(historyType: HistoryType) {
        UserDefaults.standard.set(historyType.rawValue, forKey: historyTypeKey)
    }
    
    var historyType: HistoryType = UserPreferences.readLastUsedHistoryType() {
        didSet {
            UserPreferences.writeLastUsedHistoryType(historyType: historyType)
        }
    }

    // OCR Model
    
    private static let ocrModelKey = "config.ocrModel"
    
    private static func readOcrModel() -> OcrModel {
        guard let rawValue = UserDefaults.standard.string(forKey: ocrModelKey),
              let ocrModel = OcrModel(rawValue: rawValue) else {
            return .googleMLKit
        }
        return ocrModel
    }
    
    private static func writeOcrModel(ocrModel: OcrModel) {
        UserDefaults.standard.set(ocrModel.rawValue, forKey: ocrModelKey)
    }
    
    @ObservationIgnored var ocrModel: OcrModel = UserPreferences.readOcrModel() {
        didSet {
            UserPreferences.writeOcrModel(ocrModel: ocrModel)
        }
    }
}
