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
    let ingredients: [IngredientEntry]?
    
    let images: [ScanProductImage]?
    let netQuantity: String?
    
    enum CodingKeys: String, CodingKey {
        case name, brand, ingredients, images
        case netQuantity = "net_quantity"
    }
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

struct ScanProductImage: Codable {
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
