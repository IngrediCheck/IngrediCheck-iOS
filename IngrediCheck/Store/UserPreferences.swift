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
    
    @MainActor public func clearAll() {
        UserDefaults.standard.removeObject(forKey: UserPreferences.captureTypeKey)
        UserDefaults.standard.removeObject(forKey: UserPreferences.ocrModelKey)
        UserDefaults.standard.removeObject(forKey: UserPreferences.startScanningOnAppStartKey)
        
        // Clear rating prompt tracking keys
        UserDefaults.standard.removeObject(forKey: UserPreferences.successfulScanCountKey)
        UserDefaults.standard.removeObject(forKey: UserPreferences.lastRatingPromptDateKey)
        UserDefaults.standard.removeObject(forKey: UserPreferences.ratingPromptCountKey)
        UserDefaults.standard.removeObject(forKey: UserPreferences.ratingPromptYearStartKey)
        UserDefaults.standard.removeObject(forKey: UserPreferences.fibonacciIndexKey)
        UserDefaults.standard.removeObject(forKey: UserPreferences.lastPromptDismissTimeKey)
        
        // Reset properties to default values
        captureType = .barcode
        ocrModel = .googleMLKit
        startScanningOnAppStart = false
        
        // Reset rating prompt tracking properties
        successfulScanCount = 0
        lastRatingPromptDate = nil
        ratingPromptCount = 0
        ratingPromptYearStart = nil
        fibonacciIndex = 0
        lastPromptDismissTime = nil
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
    private static let fibonacciIndexKey = "config.fibonacciIndex"
    private static let lastPromptDismissTimeKey = "config.lastPromptDismissTime"
    
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
    
    private static func readFibonacciIndex() -> Int {
        return UserDefaults.standard.integer(forKey: fibonacciIndexKey)
    }
    
    private static func readLastPromptDismissTime() -> Date? {
        return UserDefaults.standard.object(forKey: lastPromptDismissTimeKey) as? Date
    }
    
    @ObservationIgnored private var successfulScanCount: Int = UserPreferences.readSuccessfulScanCount()
    @ObservationIgnored private var lastRatingPromptDate: Date? = UserPreferences.readLastRatingPromptDate()
    @ObservationIgnored private var ratingPromptCount: Int = UserPreferences.readRatingPromptCount()
    @ObservationIgnored private var ratingPromptYearStart: Date? = UserPreferences.readRatingPromptYearStart()
    @ObservationIgnored private var fibonacciIndex: Int = UserPreferences.readFibonacciIndex()
    @ObservationIgnored private var lastPromptDismissTime: Date? = UserPreferences.readLastPromptDismissTime()
    
    /// Increment the successful scan counter
    func incrementScanCount() {
        successfulScanCount += 1
        UserDefaults.standard.set(successfulScanCount, forKey: UserPreferences.successfulScanCountKey)
    }
    
    /// Check if we can prompt for a rating based on Apple's guidelines and Fibonacci series
    /// - Uses Fibonacci series for scan count requirements (3, 5, 8, 13, 21...)
    /// - Maximum 3 prompts per 365-day period
    /// - Minimum 30 days between prompts
    func canPromptForRating() -> Bool {
        let now = Date()
        
        // Reset yearly counter if needed (365 days have passed)
        if let yearStart = ratingPromptYearStart {
            let daysSinceYearStart = Calendar.current.dateComponents([.day], from: yearStart, to: now).day ?? 0
            if daysSinceYearStart >= 365 {
                // Reset for new year
                ratingPromptCount = 0
                ratingPromptYearStart = now
                fibonacciIndex = 0
                UserDefaults.standard.set(ratingPromptCount, forKey: UserPreferences.ratingPromptCountKey)
                UserDefaults.standard.set(ratingPromptYearStart, forKey: UserPreferences.ratingPromptYearStartKey)
                UserDefaults.standard.set(fibonacciIndex, forKey: UserPreferences.fibonacciIndexKey)
            }
        }
        
        // Check if we've already shown 3 prompts this year
        guard ratingPromptCount < 3 else {
            return false
        }
        
        // Check if enough time has passed since last prompt (30 days or based on dismissal)
        if let lastPrompt = lastRatingPromptDate {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastPrompt, to: now).day ?? 0
            
            // If user likely cancelled (prompt dismissed quickly), use shorter interval
            if let dismissTime = lastPromptDismissTime,
               dismissTime.timeIntervalSince(lastPrompt) < 5.0 {
                // User cancelled - use shorter interval (7 days instead of 30)
                guard daysSinceLastPrompt >= 7 else {
                    return false
                }
            } else {
                // Normal interval (30 days)
                guard daysSinceLastPrompt >= 30 else {
                    return false
                }
            }
        }
        
        // Check if we have enough scans based on Fibonacci series
        let requiredScans = fibonacciNumber(at: fibonacciIndex)
        guard successfulScanCount >= requiredScans else {
            return false
        }
        
        return true
    }
    
    /// Calculate Fibonacci number at given index (starting from 3: 3, 5, 8, 13, 21, 34...)
    private func fibonacciNumber(at index: Int) -> Int {
        if index == 0 { return 3 }  // First prompt after 3 scans
        if index == 1 { return 5 }  // Second prompt after 5 more scans (total 8)
        if index == 2 { return 8 }  // Third prompt after 8 more scans (total 16)
        
        // For higher indices, calculate Fibonacci
        var a = 3, b = 5
        for _ in 2...index {
            let temp = a + b
            a = b
            b = temp
        }
        return b
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
        
        // Increment Fibonacci index for next prompt
        fibonacciIndex += 1
        UserDefaults.standard.set(fibonacciIndex, forKey: UserPreferences.fibonacciIndexKey)
        
        // Reset scan counter after showing prompt
        successfulScanCount = 0
        UserDefaults.standard.set(successfulScanCount, forKey: UserPreferences.successfulScanCountKey)
        
        // Set up dismissal tracking (we'll detect cancellation based on timing)
        lastPromptDismissTime = nil
        UserDefaults.standard.removeObject(forKey: UserPreferences.lastPromptDismissTimeKey)
    }
    
    /// Record when the rating prompt was dismissed (to detect cancellation)
    func recordPromptDismissal() {
        lastPromptDismissTime = Date()
        UserDefaults.standard.set(lastPromptDismissTime, forKey: UserPreferences.lastPromptDismissTimeKey)
    }
}
