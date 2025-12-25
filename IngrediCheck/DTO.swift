import Foundation
import SwiftUI

class DTO {

    enum ImageLocationInfo: Codable, Equatable, Hashable {
        case url(URL)
        case imageFileHash(String)
        
        enum CodingKeys: String, CodingKey {
            case url
            case imageFileHash
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let urlString = try container.decodeIfPresent(String.self, forKey: .url),
               let url = URL(string: urlString) {
                self = .url(url)
            } else if let imageFileHash = try container.decodeIfPresent(String.self, forKey: .imageFileHash) {
                self = .imageFileHash(imageFileHash)
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Unable to decode ImageLocationInfo"))
            }
        }
    }
    
    struct Ingredient: Codable, Hashable {
        let name: String
        let vegan: Bool?
        let vegetarian: Bool?
        let ingredients: [Ingredient]
        
        enum CodingKeys: String, CodingKey {
            case name
            case vegan
            case vegetarian
            case ingredients
        }
        
        // Public initializer for creating Ingredient instances
        init(name: String, vegan: Bool? = nil, vegetarian: Bool? = nil, ingredients: [Ingredient] = []) {
            self.name = name
            self.vegan = vegan
            self.vegetarian = vegetarian
            self.ingredients = ingredients
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            vegan = try Ingredient.decodeYesNoMaybe(from: container, forKey: .vegan)
            vegetarian = try Ingredient.decodeYesNoMaybe(from: container, forKey: .vegetarian)
            ingredients = try container.decodeIfPresent([Ingredient].self, forKey: .ingredients) ?? []
        }
        
        private static func decodeYesNoMaybe(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Bool? {
            if let value = try container.decodeIfPresent(String.self, forKey: key) {
                switch value {
                case "yes":
                    return true
                case "no":
                    return false
                default:
                    return nil
                }
            } else {
                return nil
            }
        }
    }
    
    struct AnnotatedIngredient {
        let name: String
        let safetyRecommendation: SafetyRecommendation
        let reasoning: String?
        let preference: String?
        let ingredient: [AnnotatedIngredient]
    }
    
    struct DecoratedIngredientListFragment {
        let fragment: String
        let safetyRecommendation: SafetyRecommendation
        let reasoning: String?
        let preference: String?
    }
    
    struct HistoryItem: Codable, Hashable, Equatable {
        let created_at: String
        let client_activity_id: String
        let barcode: String?
        let brand: String?
        let name: String?
        let ingredients: [Ingredient]
        let images: [ImageLocationInfo]
        let ingredient_recommendations: [IngredientRecommendation]
        let rating: Int
        let favorited: Bool

        func calculateMatch() -> ProductRecommendation {
            var result: ProductRecommendation = .match
            for recommendation in ingredient_recommendations {
                switch recommendation.safetyRecommendation {
                case .definitelyUnsafe:
                    result = .notMatch
                case .maybeUnsafe:
                    if result == .match {
                        result = .needsReview
                    }
                default:
                    break
                }
            }
            return result
        }
        
        func toColor() -> Color {
            switch calculateMatch() {
            case .match:
                Color.success100
            case .notMatch:
                Color.fail100
            case .needsReview:
                Color.warning100
            }
        }
        
        func convertISODateToLocalDateString() -> String? {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            guard let date = isoFormatter.date(from: created_at) else {
                print("Invalid date string")
                return nil
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd yyyy"
            dateFormatter.timeZone = TimeZone.current

            let localDateString = dateFormatter.string(from: date)
            return localDateString
        }

        func relativeTimeDescription(now: Date = Date()) -> String {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            guard let date = isoFormatter.date(from: created_at) else {
                return ""
            }

            let interval = now.timeIntervalSince(date)
            let seconds = Int(interval)

            if seconds < 60 {
                return "Just now"
            }

            let minutes = seconds / 60
            if minutes < 60 {
                return "\(minutes) min ago"
            }

            let hours = minutes / 60
            if hours < 24 {
                return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
            }

            let days = hours / 24
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
    }
    
    struct ListItem: Codable, Hashable, Equatable {
        let created_at: String
        let list_id: String
        let list_item_id: String
        let barcode: String?
        let brand: String?
        let name: String?
        let ingredients: [Ingredient]
        let images: [ImageLocationInfo]
        
        func convertISODateToLocalDateString() -> String? {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            guard let date = isoFormatter.date(from: created_at) else {
                print("Invalid date string")
                return nil
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd yyyy"
            dateFormatter.timeZone = TimeZone.current

            let localDateString = dateFormatter.string(from: date)
            return localDateString
        }
    }
    
    struct Product: Codable, Hashable {
        let barcode: String?
        let brand: String?
        let name: String?
        let ingredients: [Ingredient]
        let images: [ImageLocationInfo]

        private func productHasIngredient(ingredientName: String) -> Bool {
            func inner(ingredients: [Ingredient]) -> Bool {
                return ingredients.contains { i in
                    if i.name.localizedCaseInsensitiveContains(ingredientName) {
                        return true
                    }
                    return inner(ingredients: i.ingredients)
                }
            }
            return inner(ingredients: self.ingredients)
        }
        
        private func ingredientToString(_ ingredient: Ingredient) -> String {
            if ingredient.ingredients.isEmpty {
                return ingredient.name
            } else {
                return ingredient.name
                    + " ("
                    + ingredient.ingredients.map { i in
                        ingredientToString(i)
                      }
                      .joined(separator: ", ")
                      .capitalized
                    + ")"
            }
        }
        
        public var ingredientsListAsString: String {
            return ingredients.map { ingredient in
                ingredientToString(ingredient)
            }
            .joined(separator: ", ")
            .capitalized
        }

        func calculateMatch(
            ingredientRecommendations: [IngredientRecommendation]
        ) -> ProductRecommendation {
            var result: ProductRecommendation = .match
            for recommendation in ingredientRecommendations {
                if productHasIngredient(ingredientName: recommendation.ingredientName) {
                    switch recommendation.safetyRecommendation {
                    case .definitelyUnsafe:
                        result = .notMatch
                    case .maybeUnsafe:
                        if result == .match {
                            result = .needsReview
                        }
                    default:
                        break
                    }
                }
            }
            return result
        }
    }
    
    enum SafetyRecommendation: String, Codable {
        case maybeUnsafe = "MaybeUnsafe"
        case definitelyUnsafe = "DefinitelyUnsafe"
        case safe = "Safe"
        case none = "None"
    }
    
    struct IngredientRecommendation: Codable, Equatable, Hashable {
        let ingredientName: String
        let safetyRecommendation: SafetyRecommendation
        let reasoning: String
        let preference: String
    }
    
    enum ProductRecommendation {
        case match
        case needsReview
        case notMatch
    }

    struct ImageInfo: Codable {
        let imageFileHash: String
        let imageOCRText: String
        let barcode: String?
    }
    
    struct FeedbackData: Codable {
        var rating: Int?
        var reasons: [String]?
        var note: String?
        var images: [ImageInfo]?
    }

    struct DietaryPreference: Codable, Identifiable, Equatable {
        let text: String
        let annotatedText: String
        let id: Int
    }

    enum PreferenceValidationResult: Codable {

        case success(DietaryPreference)
        case failure(explanation: String)
        
        enum CodingKeys: String, CodingKey {
            case result, explanation
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let result = try container.decode(String.self, forKey: .result)
            
            switch result {
            case "success":
                let dietaryPreference = try DietaryPreference(from: decoder)
                self = .success(dietaryPreference)
            case "failure":
                let explanation = try container.decode(String.self, forKey: .explanation)
                self = .failure(explanation: explanation)
            default:
                throw DecodingError.dataCorruptedError(forKey: .result, in: container, debugDescription: "Unexpected result value")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .success(let dietaryPreference):
                try container.encode("success", forKey: .result)
                try container.encode(dietaryPreference, forKey: .result)
            case .failure(let explanation):
                try container.encode("failure", forKey: .result)
                try container.encode(explanation, forKey: .explanation)
            }
        }
    }

    static func decoratedIngredientsList(
        ingredients: [Ingredient],
        ingredientRecommendations: [IngredientRecommendation]?
    ) -> [DecoratedIngredientListFragment] {
        func annotatedIngredients(ingredients: [Ingredient]) -> [AnnotatedIngredient] {
            return ingredients.map { i in
                let recommendation = ingredientRecommendations?.first { r in
                    return i.name.localizedCaseInsensitiveContains(r.ingredientName)
                }
                if let recommendation {
                    return AnnotatedIngredient(
                        name: i.name,
                        safetyRecommendation: recommendation.safetyRecommendation,
                        reasoning: recommendation.reasoning,
                        preference: recommendation.preference,
                        ingredient: annotatedIngredients(ingredients: i.ingredients)
                    )
                } else {
                    return AnnotatedIngredient(
                        name: i.name,
                        safetyRecommendation: .safe,
                        reasoning: nil,
                        preference: nil,
                        ingredient: annotatedIngredients(ingredients: i.ingredients)
                    )
                }
            }
        }
        func decoratedIngredientListFragments(annotatedIngredients: [AnnotatedIngredient]) -> [DecoratedIngredientListFragment] {
            var result: [DecoratedIngredientListFragment] = []
            for (i, ai) in annotatedIngredients.enumerated() {
                if ai.ingredient.isEmpty {
                    var fragment = ai.name.capitalized
                    if i != (annotatedIngredients.count - 1) {
                        fragment += ", "
                    }
                    result.append(DecoratedIngredientListFragment(
                        fragment: fragment,
                        safetyRecommendation: ai.safetyRecommendation,
                        reasoning: ai.reasoning,
                        preference: ai.preference
                    ))
                } else {
                    result.append(contentsOf: [
                        DecoratedIngredientListFragment(
                            fragment: ai.name.capitalized + " ",
                            safetyRecommendation: ai.safetyRecommendation,
                            reasoning: ai.reasoning,
                            preference: ai.preference
                        ),
                        DecoratedIngredientListFragment(
                            fragment: "(",
                            safetyRecommendation: .none,
                            reasoning: nil,
                            preference: nil
                        )
                    ])
                    var subFragments = decoratedIngredientListFragments(annotatedIngredients: ai.ingredient)
                    let suffix = (i == annotatedIngredients.count - 1) ? ")" : "), "
                    let lastFragment = DecoratedIngredientListFragment(
                        fragment: subFragments.last!.fragment + suffix,
                        safetyRecommendation: subFragments.last!.safetyRecommendation,
                        reasoning: subFragments.last?.reasoning,
                        preference: subFragments.last?.preference
                    )
                    subFragments[subFragments.count - 1] = lastFragment
                    result.append(contentsOf: subFragments)
                }
            }
            return result
        }
        func splitStringPreservingSpaces(_ input: String) -> [String] {
            var result = input.split(separator: " ", omittingEmptySubsequences: true).map { String($0) + " " }

            if let last = result.last, input.last != " " {
                result[result.count - 1] = last.trimmingCharacters(in: .whitespaces)
            }

            return result
        }
        func splitDecoratedFragmentsIfNeeded(decoratedFragments: [DecoratedIngredientListFragment]) -> [DecoratedIngredientListFragment] {
            var result: [DecoratedIngredientListFragment] = []
            for fragment in decoratedFragments {
                if case .safe = fragment.safetyRecommendation {
                    for word in splitStringPreservingSpaces(fragment.fragment) {
                        result.append(DecoratedIngredientListFragment(
                            fragment: word,
                            safetyRecommendation: .safe,
                            reasoning: nil,
                            preference: nil
                        ))
                    }
                } else {
                    result.append(fragment)
                }
            }
            return result
        }
        let annotatedIngredients = annotatedIngredients(ingredients: ingredients)
        let decoratedFragments = decoratedIngredientListFragments(annotatedIngredients: annotatedIngredients)
        return splitDecoratedFragmentsIfNeeded(decoratedFragments: decoratedFragments)
    }
    
    // MARK: - Scan API Models
    
    // Helper type to decode ingredients that can be either strings or Ingredient objects
    private struct IngredientOrString: Codable {
        let ingredient: Ingredient
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            // Try to decode as string first (most common case)
            if let name = try? container.decode(String.self) {
                self.ingredient = Ingredient(name: name, vegan: nil, vegetarian: nil, ingredients: [])
            } else {
                // If string fails, decode as Ingredient object using the same decoder
                // The decoder position hasn't advanced because singleValueContainer doesn't consume
                // the value until a successful decode, so we can decode as Ingredient
                self.ingredient = try Ingredient(from: decoder)
            }
        }
        
        func encode(to encoder: Encoder) throws {
            try ingredient.encode(to: encoder)
        }
    }
    
    struct ScanProductInfo: Codable, Hashable {
        let name: String?
        let brand: String?
        let ingredients: [Ingredient]
        let images: [ScanImageInfo]?
        
        enum CodingKeys: String, CodingKey {
            case name
            case brand
            case ingredients
            case images
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            brand = try container.decodeIfPresent(String.self, forKey: .brand)
            images = try container.decodeIfPresent([ScanImageInfo].self, forKey: .images)
            
            // Handle ingredients - can be null, array of strings, or array of Ingredient objects
            if container.contains(.ingredients) {
                // Check if it's null
                if try container.decodeNil(forKey: .ingredients) {
                    // ingredients is null, use empty array
                    ingredients = []
                } else {
                    // Decode as array of IngredientOrString, then extract the ingredients
                    let ingredientOrStrings = try container.decode([IngredientOrString].self, forKey: .ingredients)
                    ingredients = ingredientOrStrings.map { $0.ingredient }
                }
            } else {
                // ingredients key is missing, use empty array
                ingredients = []
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(brand, forKey: .brand)
            try container.encode(ingredients, forKey: .ingredients)
            try container.encodeIfPresent(images, forKey: .images)
        }
    }
    
    struct ScanImageInfo: Codable, Hashable {
        let url: String?
    }
    
    struct ScanAnalysisResult: Codable, Hashable {
        let overall_analysis: String
        let overall_match: String  // "matched", "uncertain", "unmatched"
        let ingredient_analysis: [ScanIngredientAnalysis]
        
        enum CodingKeys: String, CodingKey {
            case overall_analysis
            case overallAnalysis
            case overall_match
            case overallMatch
            case ingredient_analysis
            case flaggedIngredients
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Decode overall_analysis - try snake_case first (from GET /scan endpoint), then camelCase (from SSE events)
            if let value = try? container.decode(String.self, forKey: .overall_analysis) {
                overall_analysis = value
            } else {
                overall_analysis = try container.decode(String.self, forKey: .overallAnalysis)
            }
            
            // Decode overall_match - try snake_case first (from GET /scan endpoint), then camelCase (from SSE events)
            if let value = try? container.decode(String.self, forKey: .overall_match) {
                overall_match = value
            } else {
                overall_match = try container.decode(String.self, forKey: .overallMatch)
            }
            
            // Decode ingredient_analysis - try ingredient_analysis first, then flaggedIngredients, default to empty
            if let value = try? container.decodeIfPresent([ScanIngredientAnalysis].self, forKey: .ingredient_analysis) {
                ingredient_analysis = value
            } else {
                // flaggedIngredients might be a different structure, so we'll default to empty for now
                // If backend sends ingredient_analysis later, it will be picked up
                ingredient_analysis = []
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Encode to snake_case (what GET /scan endpoint expects)
            try container.encode(overall_analysis, forKey: .overall_analysis)
            try container.encode(overall_match, forKey: .overall_match)
            try container.encode(ingredient_analysis, forKey: .ingredient_analysis)
        }
    }
    
    struct ScanIngredientAnalysis: Codable, Hashable {
        let ingredient: String
        let match: String  // "unmatched", "uncertain"
        let reasoning: String
        let members_affected: [String]
    }
    
    // SSE Event payloads
    struct ScanProductInfoEvent: Codable {
        let scan_id: String
        let product_info: ScanProductInfo
        let product_info_source: String
        let images: [ScanImage]
    }
    
    struct ScanAnalysisEvent: Codable {
        let analysis_id: String?  // Optional - backend sends this but guide doesn't require it
        let analysis_status: String
        let analysis_result: ScanAnalysisResult
    }
    
    // Image types in scan response
    enum ScanImage: Codable, Hashable {
        case inventory(InventoryScanImage)
        case user(UserScanImage)
        
        struct InventoryScanImage: Codable, Hashable {
            let type: String  // "inventory"
            let url: String
        }
        
        struct UserScanImage: Codable, Hashable {
            let type: String  // "user"
            let content_hash: String
            let storage_path: String?
            let status: String  // "pending", "processing", "processed", "failed"
            let extraction_error: String?
        }
        
        private enum CodingKeys: String, CodingKey {
            case type
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "inventory":
                self = .inventory(try InventoryScanImage(from: decoder))
            case "user":
                self = .user(try UserScanImage(from: decoder))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown image type: \(type)"
                )
            }
        }
        
        func encode(to encoder: Encoder) throws {
            switch self {
            case .inventory(let img):
                try img.encode(to: encoder)
            case .user(let img):
                try img.encode(to: encoder)
            }
        }
    }
    
    // Full Scan object
    struct Scan: Codable, Hashable {
        let id: String
        let scan_type: String  // "barcode" or "photo"
        let barcode: String?
        let status: String  // "idle" or "processing"
        let product_info: ScanProductInfo
        let product_info_source: String?  // "openfoodfacts", "extraction", "enriched"
        let analysis_status: String?  // "analyzing", "complete", "stale"
        let analysis_result: ScanAnalysisResult?
        let images: [ScanImage]
        let latest_guidance: String?
        let created_at: String
        let last_activity_at: String
    }
    
    // Submit image response
    struct SubmitImageResponse: Codable {
        let queued: Bool
        let queue_position: Int
        let content_hash: String
    }
    
    // Scan history response
    struct ScanHistoryResponse: Codable {
        let scans: [Scan]
        let total: Int
        let has_more: Bool
    }
}
