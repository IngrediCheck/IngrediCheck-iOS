import Foundation

struct MemojiSelection {
    var familyType: String
    var gesture: String
    var hair: String
    var skinTone: String
    var accessory: String?
    var colorThemeIcon: String?
    
    var backgroundHex: String? {
        MemojiSelection.colorHexMap[colorThemeIcon ?? ""]
    }
    
    func toMemojiRequest() -> MemojiRequest {
        MemojiRequest(
            familyType: familyType,
            gesture: gesture,
            hair: hair,
            skinTone: skinTone,
            accessories: accessory.map { [$0] } ?? [],
            background: "transparent", // user color applied in UI
            size: "1024x1024",
            model: "gpt-image-1",
            subscriptionTier: "monthly_basic"
        )
    }
    
    private static let colorHexMap: [String: String] = [
        "pastel-blue": "A7C7E7",
        "warm-pink": "F6B0C3",
        "soft-green": "A8E6A1",
        "lavender": "C7B7E5",
        "cream": "F5E6C8",
        "mint": "B8F2E6",
        "transparent": "FFFFFF00"
    ]
}

