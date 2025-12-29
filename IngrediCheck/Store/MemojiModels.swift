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
    let mood: String? // Visual description of facial expression and body language
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
    
    // Generate visual description of facial expression and body language
    private func generateVisualMood() -> String {
        let familyTypeLower = familyType.lowercased()
        
        // Check category: baby, young, adult, or older
        let isBaby = familyTypeLower.contains("baby")
        let isYoung = familyTypeLower.contains("young")
        let isOlder = familyTypeLower.contains("grandfather") || familyTypeLower.contains("grandmother")
        
        if isBaby {
            // Baby (0-4) - very young with one tooth showing
            let babyVisualMoodStrings = [
                "smiling widely with one tooth showing in the middle and bright, cheerful eyes",
                "grinning with open mouth showing one front tooth in the middle and crinkled eyes",
                "laughing with one tooth visible in the middle, head slightly tilted, and joyful expression",
                "beaming with wide smile, one tooth showing in the middle, and sparkling eyes",
                "smiling with one front tooth visible in the middle and bright, friendly eyes",
                "grinning ear to ear with one tooth showing in the middle and raised eyebrows",
                "laughing with open mouth, one tooth in the middle, crinkled eyes, and joyful expression",
                "smiling broadly with one tooth showing in the middle and cheerful, energetic expression",
                "grinning widely with one front tooth visible in the middle and happy, bright eyes",
                "beaming with one tooth showing in the middle, radiant smile, and cheerful eyes",
                "smiling with one tooth in the middle, warm eyes, and genuine, joyful expression",
                "laughing with head back, one tooth visible in the middle, and very happy expression",
                "grinning with one tooth showing in the middle, wide smile, raised cheeks, and joyful expression",
                "smiling widely with one front tooth in the middle and bright, cheerful expression",
                "laughing with one tooth visible in the middle, open mouth, and joyful, energetic expression"
            ]
            return babyVisualMoodStrings.randomElement() ?? "smiling widely with one tooth showing in the middle and bright, cheerful eyes"
        } else if isYoung {
            // Young/Teenager (4-25) - cool, energetic, stylish
            let youngVisualMoodStrings = [
                "smiling with cool, confident expression and bright, energetic eyes",
                "grinning with stylish smile, head slightly tilted, and trendy, youthful expression",
                "laughing with confident, cool expression and bright, playful eyes",
                "beaming with hip, modern smile and energetic, fashionable expression",
                "smiling with cool, relaxed expression and bright, confident eyes",
                "grinning with trendy smile, raised eyebrows, and stylish, youthful expression",
                "laughing with cool, open smile and bright, energetic, modern expression",
                "smiling broadly with confident, stylish expression and positive, cool energy",
                "grinning widely with hip smile and happy, trendy, youthful expression",
                "beaming with cool, radiant smile and bright, fashionable eyes",
                "smiling with confident, modern expression and genuine, cool eyes",
                "laughing with head back, stylish smile, and very happy, energetic expression",
                "grinning with cool, wide smile, raised cheeks, and trendy, joyful expression",
                "smiling widely with confident, modern expression and bright, cool eyes",
                "laughing with open mouth, stylish expression, and joyful, fashionable energy"
            ]
            return youngVisualMoodStrings.randomElement() ?? "smiling with cool, confident expression and bright, energetic eyes"
        } else if isOlder {
            // Older adult (grandfather/grandmother) - gentle, wise
            let olderVisualMoodStrings = [
                "smiling warmly with gentle, wise eyes and kind expression",
                "grinning with soft smile showing gentle wrinkles around eyes and content expression",
                "laughing with head slightly tilted, warm eyes, and joyful, peaceful expression",
                "beaming with gentle smile, bright eyes, and serene, happy expression",
                "smiling with warm, friendly eyes and relaxed, content expression",
                "grinning with soft laugh, gentle expression, and kind, cheerful eyes",
                "smiling with closed mouth, wise eyes, and peaceful, content expression",
                "laughing with gentle smile, crinkled eyes showing wisdom, and joyful expression",
                "smiling broadly with warm, kind eyes and positive, serene energy",
                "grinning widely with gentle smile, bright eyes, and happy, peaceful expression",
                "smiling with warm, wise eyes and genuine, content expression",
                "laughing with head back, gentle smile, and very happy, peaceful expression",
                "beaming with radiant, gentle smile and bright, kind eyes",
                "smiling with relaxed, wise expression and friendly, content eyes",
                "grinning with gentle smile, raised cheeks showing wrinkles, and joyful, peaceful expression"
            ]
            return olderVisualMoodStrings.randomElement() ?? "smiling warmly with gentle, wise eyes and kind expression"
        } else {
            // Adult (father/mother) - standard cheerful
            let adultVisualMoodStrings = [
                "smiling widely with bright eyes and cheerful expression",
                "grinning with open mouth showing teeth and crinkled eyes",
                "laughing with head slightly tilted back and joyful expression",
                "beaming with wide smile and sparkling eyes",
                "smiling warmly with gentle eyes and relaxed expression",
                "grinning ear to ear with raised eyebrows and happy expression",
                "smiling with closed mouth and bright, friendly eyes",
                "laughing with open mouth, crinkled eyes, and joyful expression",
                "smiling broadly with cheerful face and positive energy",
                "grinning widely with bright smile and happy, energetic expression",
                "smiling with warm eyes and genuine, joyful expression",
                "laughing with head back, open mouth, and very happy expression",
                "beaming with radiant smile and bright, cheerful eyes",
                "smiling with relaxed, content expression and friendly eyes",
                "grinning with wide smile, raised cheeks, and joyful expression"
            ]
            return adultVisualMoodStrings.randomElement() ?? "smiling widely with bright eyes and cheerful expression"
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
            colorTheme: mapColorThemeToAPIFormat(colorThemeIcon),
            mood: generateVisualMood()
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

