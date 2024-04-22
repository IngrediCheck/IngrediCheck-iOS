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
    
    public func clearAll() {
        UserDefaults.standard.removeObject(forKey: UserPreferences.captureTypeKey)
        UserDefaults.standard.removeObject(forKey: UserPreferences.ocrModelKey)
        UserDefaults.standard.removeObject(forKey: UserPreferences.startScanningOnAppStartKey)
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
    
    // StartScanningOnAppStart
    
    public static let startScanningOnAppStartKey = "config.startScanningOnAppStart"
    
    private static func readStartScanningOnAppStart() -> Bool {
        // Note: UserDefaults.standard.bool returns false if value does not exist,
        // which is not what we want here.
        guard let value = UserDefaults.standard.value(forKey: UserPreferences.startScanningOnAppStartKey) else {
            return false
        }
        return value as? Bool ?? false
    }
    
    @ObservationIgnored var startScanningOnAppStart: Bool =
        UserPreferences.readStartScanningOnAppStart() {
            didSet {
                UserDefaults.standard.setValue(
                    startScanningOnAppStart,
                    forKey: UserPreferences.startScanningOnAppStartKey
                )
            }
        }
}
