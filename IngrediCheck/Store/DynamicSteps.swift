import Foundation
import SwiftUI

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
    let individual: DynamicHeaderVariant
    let family: DynamicHeaderVariant
    let singleMember: DynamicHeaderVariant?

    enum CodingKeys: String, CodingKey {
        case iconURL = "iconUrl"
        case name
        case individual
        case family
        case singleMember
    }
}

struct DynamicHeaderVariant: Codable {
    let question: String
    let description: String?
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

// MARK: - Loader

/// Helper for loading the dynamic onboarding configuration from the bundled JSON.
enum DynamicStepsProvider {
    static func loadSteps() -> [DynamicStep] {
        // When this runs inside the preview target, the JSON should be part of
        // the IngrediCheckPreview app bundle with the same filename.
        guard let url = Bundle.main.url(forResource: "dynamicJsonData", withExtension: "json") else {
            assertionFailure("dynamicJsonData.json not found in bundle")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(DynamicStepsPayload.self, from: data)
            return payload.steps
        } catch {
            assertionFailure("Failed to decode dynamicJsonData.json: \(error)")
            return []
        }
    }
}

