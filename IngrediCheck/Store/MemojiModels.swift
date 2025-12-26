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
    let mood: String // Random funny and happy string for emoji generation
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
    
    // Generate a random funny and happy string for emoji generation
    private static func generateFunnyHappyMood() -> String {
        let funnyHappyStrings = [
            "funny and enjoying life with a big smile",
            "extremely happy and having a great time",
            "laughing and full of joy",
            "cheerful and playful with lots of energy",
            "super happy and excited about everything",
            "grinning widely and having fun",
            "joyful and carefree with a bright smile",
            "hilariously happy and full of laughter",
            "ecstatically happy and enjoying every moment",
            "beaming with happiness and having a blast",
            "radiating joy and positive energy",
            "laughing out loud and having the best time",
            "overflowing with happiness and cheer",
            "delightfully happy and full of life",
            "bursting with joy and excitement"
        ]
        return funnyHappyStrings.randomElement() ?? "funny and enjoying life with a big smile"
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
            subscriptionTier: "monthly_basic",
            mood: MemojiSelection.generateFunnyHappyMood()
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

