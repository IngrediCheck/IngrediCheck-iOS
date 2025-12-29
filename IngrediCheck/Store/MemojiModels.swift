import Foundation

struct MemojiRequest: Encodable {
    let familyType: String
    let gesture: String
    let hair: String
    let skinTone: String
    let accessories: [String]
    let background: String
    let size: String
    let model: String
    let subscriptionTier: String
    let colorTheme: String? // Color theme for clothing and background style
}

struct MemojiResponse: Decodable {
    let success: Bool
    let cached: Bool?
    let imageUrl: String?
    
    private enum CodingKeys: String, CodingKey {
        case success
        case cached
        case imageUrl
        case image_url
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        cached = try container.decodeIfPresent(Bool.self, forKey: .cached)
        // Support both camelCase (`imageUrl`) and snake_case (`image_url`) from the API
        imageUrl =
            (try? container.decodeIfPresent(String.self, forKey: .imageUrl)) ??
            (try? container.decodeIfPresent(String.self, forKey: .image_url))
    }
}

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
    
    // Map hair icon to API format
    private func mapHairToAPIFormat(_ hairIcon: String) -> String {
        switch hairIcon.lowercased() {
        case "short-hair": return "short"
        case "long-hair": return "long"
        case "curly-hair": return "curly"
        case "medium-curely": return "curly"
        case "short spiky": return "short spiky"
        case "braided": return "braided"
        case "ponytail": return "ponytail"
        case "bun": return "bun"
        case "bald": return "bald"
        default: return hairIcon.lowercased()
        }
    }
    
    // Map color theme icon to API format
    private func mapColorThemeToAPIFormat(_ colorThemeIcon: String?) -> String? {
        guard let icon = colorThemeIcon else { return nil }
        switch icon.lowercased() {
        case "pastel-blue": return "pastel-blue"
        case "warm-pink": return "warm-pink"
        case "soft-green": return "soft-green"
        case "lavender": return "lavender"
        case "cream": return "cream"
        case "mint": return "mint"
        case "transparent": return "transparent"
        default: return icon.lowercased()
        }
    }
    
    func toMemojiRequest() -> MemojiRequest {
        MemojiRequest(
            familyType: familyType,
            gesture: gesture,
            hair: mapHairToAPIFormat(hair),
            skinTone: skinTone,
            accessories: accessory.map { [$0] } ?? [],
            background: "transparent", // user color applied in UI
            size: "1024x1024",
            model: "gpt-image-1",
            subscriptionTier: "monthly_basic",
            colorTheme: mapColorThemeToAPIFormat(colorThemeIcon)
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

