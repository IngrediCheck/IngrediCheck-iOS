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
    
    // MARK: - Rating Prompt Tracking
    
    private static let successfulScanCountKey = "config.successfulScanCount"
    private static let lastRatingPromptDateKey = "config.lastRatingPromptDate"
    private static let ratingPromptCountKey = "config.ratingPromptCount"
    private static let ratingPromptYearStartKey = "config.ratingPromptYearStart"
    
    private static func readSuccessfulScanCount() -> Int {
        return UserDefaults.standard.integer(forKey: successfulScanCountKey)
    }
    
    private static func readLastRatingPromptDate() -> Date? {
        return UserDefaults.standard.object(forKey: lastRatingPromptDateKey) as? Date
    }
    
    private static func readRatingPromptCount() -> Int {
        return UserDefaults.standard.integer(forKey: ratingPromptCountKey)
    }
    
    private static func readRatingPromptYearStart() -> Date? {
        return UserDefaults.standard.object(forKey: ratingPromptYearStartKey) as? Date
    }
    
    @ObservationIgnored private var successfulScanCount: Int = UserPreferences.readSuccessfulScanCount()
    @ObservationIgnored private var lastRatingPromptDate: Date? = UserPreferences.readLastRatingPromptDate()
    @ObservationIgnored private var ratingPromptCount: Int = UserPreferences.readRatingPromptCount()
    @ObservationIgnored private var ratingPromptYearStart: Date? = UserPreferences.readRatingPromptYearStart()
    
    /// Increment the successful scan counter
    func incrementScanCount() {
        successfulScanCount += 1
        UserDefaults.standard.set(successfulScanCount, forKey: UserPreferences.successfulScanCountKey)
    }
    
    /// Check if we can prompt for a rating based on Apple's guidelines
    /// - Minimum 5 successful scans
    /// - Maximum 3 prompts per 365-day period
    /// - Minimum 30 days between prompts
    func canPromptForRating() -> Bool {
        let now = Date()
        
        // Check if we have enough successful scans
        guard successfulScanCount >= 5 else {
            return false
        }
        
        // Reset yearly counter if needed (365 days have passed)
        if let yearStart = ratingPromptYearStart {
            let daysSinceYearStart = Calendar.current.dateComponents([.day], from: yearStart, to: now).day ?? 0
            if daysSinceYearStart >= 365 {
                // Reset for new year
                ratingPromptCount = 0
                ratingPromptYearStart = now
                UserDefaults.standard.set(ratingPromptCount, forKey: UserPreferences.ratingPromptCountKey)
                UserDefaults.standard.set(ratingPromptYearStart, forKey: UserPreferences.ratingPromptYearStartKey)
            }
        }
        
        // Check if we've already shown 3 prompts this year
        guard ratingPromptCount < 3 else {
            return false
        }
        
        // Check if 30 days have passed since last prompt
        if let lastPrompt = lastRatingPromptDate {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastPrompt, to: now).day ?? 0
            guard daysSinceLastPrompt >= 30 else {
                return false
            }
        }
        
        return true
    }
    
    /// Record that a rating prompt was shown
    func recordRatingPrompt() {
        let now = Date()
        
        // Initialize year start if needed
        if ratingPromptYearStart == nil {
            ratingPromptYearStart = now
            UserDefaults.standard.set(ratingPromptYearStart, forKey: UserPreferences.ratingPromptYearStartKey)
        }
        
        // Update prompt count and date
        ratingPromptCount += 1
        lastRatingPromptDate = now
        
        UserDefaults.standard.set(ratingPromptCount, forKey: UserPreferences.ratingPromptCountKey)
        UserDefaults.standard.set(lastRatingPromptDate, forKey: UserPreferences.lastRatingPromptDateKey)
        
        // Reset scan counter after showing prompt
        successfulScanCount = 0
        UserDefaults.standard.set(successfulScanCount, forKey: UserPreferences.successfulScanCountKey)
    }
}
