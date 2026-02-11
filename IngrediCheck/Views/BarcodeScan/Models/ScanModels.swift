import SwiftUI

/// Represents the current scanning mode (barcode scanner or photo capture)
enum CameraMode {
    case scanner
    case photo
}

/// Represents different toast message states during scanning
enum ToastScanState: Equatable {
    case scanning               // user is scanning / live camera
    case extractionSuccess      // barcode extracted successfully
    case notIdentified          // product could not be identified
    case analyzing              // product detected, reading ingredients
    case match                  // product matches preferences
    case notMatch               // product does not match preferences
    case uncertain              // some ingredients are unclear
    case retry                  // retry / retake photo
    case photoGuide             // camera/photo mode guidance
    case dynamicGuidance(String) // dynamic guidance from API (photo mode)
}
