import Foundation

// MARK: - Dynamic Steps Root

struct DynamicStepsPayload: Codable {
    let steps: [DynamicStep]
}

// MARK: - Step

struct DynamicStep: Codable, Identifiable {
    let id: String
    let type: DynamicStepType
    let header: DynamicStepHeader
    let content: DynamicStepContent
}

// Using a simple string-backed enum keeps the JSON flexible if the backend
// adds a new type – unknown values will be decoded as `.unknown`.
enum DynamicStepType: String, Codable {
    case type1 = "type-1"
    case type2 = "type-2"
    case type3 = "type-3"
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? ""
        self = DynamicStepType(rawValue: rawValue) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .type1:
            try container.encode("type-1")
        case .type2:
            try container.encode("type-2")
        case .type3:
            try container.encode("type-3")
        case .unknown:
            // Persist as-is for round-tripping; you can also choose to omit or
            // encode a fallback string here depending on your needs.
            try container.encode("unknown")
        }
    }
}

// MARK: - Header

struct DynamicStepHeader: Codable {
    let iconURL: String?
    let name: String
    let question: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case iconURL = "iconUrl"
        case name
        case question
        case description
    }
}

// MARK: - Content

/// A single content wrapper that can represent all three shapes used in the JSON:
/// - `options` for simple chip lists (type-1)
/// - `subSteps` for card-based layouts (type-2)
/// - `regions` / `subRegions` for hierarchical groupings (type-3)
///
/// Only one of these will typically be non-nil per `DynamicStep`, but the model
/// is flexible enough if that ever changes.
struct DynamicStepContent: Codable {
    let options: [DynamicOption]?
    let subSteps: [DynamicSubStep]?
    let regions: [DynamicRegion]?
}

// MARK: - Reusable Leaf Types

struct DynamicOption: Codable, Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

struct DynamicSubStep: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let colorHex: String?
    let backgroundImageURL: String?
    let options: [DynamicOption]?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case colorHex = "color"
        case backgroundImageURL = "bgImageUrl"
        case options
    }
}

struct DynamicRegion: Codable, Identifiable {
    let id = UUID()
    let name: String
    let subRegions: [DynamicOption]
}


