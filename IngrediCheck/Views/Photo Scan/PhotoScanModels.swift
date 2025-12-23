import Foundation

// MARK: - Submit Image Response
struct SubmitImageResponse: Codable {
    let queued: Bool
    let queuePosition: Int
    let contentHash: String?
    
    enum CodingKeys: String, CodingKey {
        case queued
        case queuePosition = "queue_position"
        case contentHash = "content_hash"
    }
}

// MARK: - Scan Details Response
struct ScanDetailsResponse: Codable, Identifiable {
    let id: String
    let scanType: String
    let status: String
    let productInfo: ProductInfo?
    let analysisStatus: String?
    let analysisResult: AnalysisResult?
    let latestGuidance: String?
    let createdAt: String
    let lastActivityAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case scanType = "scan_type"
        case status
        case productInfo = "product_info"
        case analysisStatus = "analysis_status"
        case analysisResult = "analysis_result"
        case latestGuidance = "latest_guidance"
        case createdAt = "created_at"
        case lastActivityAt = "last_activity_at"
    }
}

struct ProductInfo: Codable {
    let name: String?
    let brand: String?
    let ingredients: [String]? // The example shows strings, but the polling response example shows objects { "name": "..." }. I should check the polling example carefully.
    // Polling example: "ingredients": [ { "name": "Carbonated Water" }, ... ]
    // Initial example: "ingredients": ["Ingredient 1", "Ingredient 2"]
    // I will support both or check which one is correct. The polling example is more detailed.
    // Let's use a custom decoding or just [IngredientItem] if I can confirm.
    // The user provided two JSONs.
    // 1. "ingredients": ["Ingredient 1", "Ingredient 2"]
    // 2. "ingredients": [ { "name": "Carbonated Water" }, ... ]
    // I'll stick to the detailed one (Polling example) as it's likely the actual implementation, or try to decode as [IngredientItem] first.
    // Actually, let's look at the "Get Scan Details (Polling)" JSON in the prompt again.
    // It says: "ingredients": ["Ingredient 1", "Ingredient 2"]
    // BUT later in "Expected Response for Dr Pepper Image":
    // "ingredients": [ { "name": "Carbonated Water" }, ... ]
    // I will assume the detailed one is correct for the final response, but maybe the initial one is valid too.
    // I'll define a struct IngredientItem.
    
    let images: [ProductImage]?
}

// Helper for ingredients which might be strings or objects
enum IngredientEntry: Codable {
    case string(String)
    case object(IngredientItem)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        if let x = try? container.decode(IngredientItem.self) {
            self = .object(x)
            return
        }
        throw DecodingError.typeMismatch(IngredientEntry.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for IngredientEntry"))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let x):
            try container.encode(x)
        case .object(let x):
            try container.encode(x)
        }
    }
    
    var name: String {
        switch self {
        case .string(let s): return s
        case .object(let o): return o.name
        }
    }
}

struct IngredientItem: Codable {
    let name: String
}

struct ProductImage: Codable {
    let url: String
}

struct AnalysisResult: Codable {
    let overallAnalysis: String?
    let overallMatch: String?
    let ingredientAnalysis: [IngredientAnalysisItem]?
    
    enum CodingKeys: String, CodingKey {
        case overallAnalysis = "overall_analysis"
        case overallMatch = "overall_match"
        case ingredientAnalysis = "ingredient_analysis"
    }
}

struct IngredientAnalysisItem: Codable {
    let ingredient: String
    let match: String
    let reasoning: String?
    let membersAffected: [String]?
    
    enum CodingKeys: String, CodingKey {
        case ingredient
        case match
        case reasoning
        case membersAffected = "members_affected"
    }
}

// MARK: - Scan History Response
struct ScanHistoryResponse: Codable {
    let scans: [ScanDetailsResponse]
    let total: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case scans
        case total
        case hasMore = "has_more"
    }
}
