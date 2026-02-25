import Foundation
import SwiftUI
import os

class DTO {

    struct Vote: Codable, Hashable {
        let id: String
        let value: String // "up" or "down"
    }

    enum ImageLocationInfo: Codable, Equatable, Hashable {
        case url(URL)
        case imageFileHash(String)  // For productimages bucket
        case scanImagePath(String)  // For scans bucket (user-uploaded scan images)
        
        enum CodingKeys: String, CodingKey {
            case url
            case imageFileHash
            case scanImagePath
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let urlString = try container.decodeIfPresent(String.self, forKey: .url),
               let url = URL(string: urlString) {
                self = .url(url)
            } else if let scanImagePath = try container.decodeIfPresent(String.self, forKey: .scanImagePath) {
                self = .scanImagePath(scanImagePath)
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
            case contains  // API may use "contains" instead of "ingredients"
        }
        
        // Convenience initializer for creating from string (for Scan API)
        init(name: String, vegan: Bool?, vegetarian: Bool?, ingredients: [Ingredient]) {
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
            
            // Handle both "ingredients" and "contains" fields
            // API sends "contains" as array of Ingredient objects with nested contains
            if let ingredientsArray = try? container.decode([Ingredient].self, forKey: .ingredients) {
                ingredients = ingredientsArray
            } else if let containsArray = try? container.decode([Ingredient].self, forKey: .contains) {
                // API uses "contains" field with nested Ingredient objects
                ingredients = containsArray
            } else if let containsStrings = try? container.decode([String].self, forKey: .contains) {
                // Fallback: "contains" as array of strings (legacy format)
                ingredients = containsStrings.map { Ingredient.parseFromString($0) }
            } else {
                ingredients = []
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            
            // Encode vegan/vegetarian as "yes"/"no" strings if present
            if let vegan = vegan {
                try container.encode(vegan ? "yes" : "no", forKey: .vegan)
            }
            if let vegetarian = vegetarian {
                try container.encode(vegetarian ? "yes" : "no", forKey: .vegetarian)
            }
            
            // Encode ingredients (not contains) - use standard format
            if !ingredients.isEmpty {
                try container.encode(ingredients, forKey: .ingredients)
            }
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

        /// Parse an ingredient from a string, handling nested format like "Chocolate (Sugar, Cocoa)"
        static func parseFromString(_ text: String) -> Ingredient {
            let trimmed = text.trimmingCharacters(in: .whitespaces)

            // Check for nested format: "Name (sub1, sub2, sub3)"
            guard let openParen = trimmed.firstIndex(of: "("),
                  let closeParen = trimmed.lastIndex(of: ")"),
                  openParen < closeParen else {
                // No nested ingredients - return simple ingredient
                return Ingredient(name: trimmed, vegan: nil, vegetarian: nil, ingredients: [])
            }

            let name = String(trimmed[..<openParen]).trimmingCharacters(in: .whitespaces)
            let nestedString = String(trimmed[trimmed.index(after: openParen)..<closeParen])

            // Split by comma, but be careful of nested parentheses
            let nestedIngredients = splitByCommaRespectingParentheses(nestedString)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { Ingredient.parseFromString($0) }  // Recursive for deep nesting

            return Ingredient(name: name, vegan: nil, vegetarian: nil, ingredients: nestedIngredients)
        }

        /// Split a string by commas while respecting nested parentheses
        private static func splitByCommaRespectingParentheses(_ text: String) -> [String] {
            var result: [String] = []
            var current = ""
            var parenDepth = 0

            for char in text {
                if char == "(" {
                    parenDepth += 1
                    current.append(char)
                } else if char == ")" {
                    parenDepth -= 1
                    current.append(char)
                } else if char == "," && parenDepth == 0 {
                    result.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            }

            if !current.isEmpty {
                result.append(current)
            }

            return result
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
                Log.debug("DTO", "Invalid date string")
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
        let claims: [String]?  // Dietary claims/tags from product (e.g., "Gluten Free", "High in Protein")

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
        let memberIdentifiers: [String]?  // Array of member IDs from members_affected
    }
    
    enum ProductRecommendation {
        case match
        case needsReview
        case notMatch
        case unknown
        case noPreferences
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
    
    struct ScanProductInfo: Codable, Hashable {
        let name: String?
        let brand: String?
        let ingredients: [Ingredient]
        let images: [ScanImageInfo]?
        let claims: [String]?  // Dietary claims/tags from product

        // Convenience initializer for creating empty ScanProductInfo
        init(name: String?, brand: String?, ingredients: [Ingredient], images: [ScanImageInfo]?, claims: [String]? = nil) {
            self.name = name
            self.brand = brand
            self.ingredients = ingredients
            self.images = images
            self.claims = claims
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            brand = try container.decodeIfPresent(String.self, forKey: .brand)
            images = try container.decodeIfPresent([ScanImageInfo].self, forKey: .images)
            claims = try container.decodeIfPresent([String].self, forKey: .claims)

            // Handle ingredients - API returns string array, convert to Ingredient objects
            if container.contains(.ingredients) {
                // Backend now only returns string arrays for ingredients
                if let stringArray = try? container.decode([String].self, forKey: .ingredients) {
                    // Parse nested format like "Dark Chocolate (Sugar, Cocoa, Vanilla)"
                    ingredients = stringArray.map { Ingredient.parseFromString($0) }
                } else {
                    // Fallback: try decoding as Ingredient objects (for backward compatibility)
                    ingredients = try container.decodeIfPresent([Ingredient].self, forKey: .ingredients) ?? []
                }
            } else {
                ingredients = []
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case name, brand, ingredients, images, claims
        }
    }
    
    struct ScanImageInfo: Codable, Hashable {
        let url: String?
    }
    
    struct ScanAnalysisResult: Codable, Hashable {
        let id: String?  // UUID - Analysis ID for feedback submission (required per API spec)
        let overall_analysis: String?
        let overall_match: String?  // "matched", "uncertain", "unmatched" - optional as it may be missing in some responses
        var ingredient_analysis: [ScanIngredientAnalysis]
        let is_stale: Bool?
        var vote: Vote?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Decode id (required per API spec for feedback submission)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            
            // Try both camelCase (overallAnalysis) and snake_case (overall_analysis)
            overall_analysis = try container.decodeIfPresent(String.self, forKey: .overall_analysis)
                ?? container.decodeIfPresent(String.self, forKey: .overallAnalysis)
            
            // Try both camelCase (overallMatch) and snake_case (overall_match) for backend compatibility
            overall_match = try container.decodeIfPresent(String.self, forKey: .overall_match)
                ?? container.decodeIfPresent(String.self, forKey: .overallMatch)
            
            // Try both camelCase (flaggedIngredients) and snake_case (ingredient_analysis)
            ingredient_analysis = try container.decodeIfPresent([ScanIngredientAnalysis].self, forKey: .ingredient_analysis)
                ?? container.decodeIfPresent([ScanIngredientAnalysis].self, forKey: .flaggedIngredients)
                ?? []
            
            // Decode is_stale (snake_case from API)
            is_stale = try container.decodeIfPresent(Bool.self, forKey: .is_stale)
            
            // Decode vote
            vote = try container.decodeIfPresent(Vote.self, forKey: .vote)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(id, forKey: .id)
            try container.encodeIfPresent(overall_analysis, forKey: .overall_analysis)
            try container.encodeIfPresent(overall_match, forKey: .overall_match)
            try container.encode(ingredient_analysis, forKey: .ingredient_analysis)
            try container.encodeIfPresent(is_stale, forKey: .is_stale)
            try container.encodeIfPresent(vote, forKey: .vote)
        }
        
        enum CodingKeys: String, CodingKey {
            case id
            case overall_analysis
            case overallAnalysis  // Support camelCase from API
            case overall_match
            case overallMatch  // Support camelCase from API
            case ingredient_analysis
            case flaggedIngredients  // Support camelCase from API
            case is_stale
            case vote
        }
    }
    
    struct ScanIngredientAnalysis: Codable, Hashable {
        let ingredient: String
        let match: String  // "unmatched", "uncertain"
        let reasoning: String
        let members_affected: [String]
        var vote: Vote?
        
        // Note: API uses snake_case (members_affected), so we use default CodingKeys
    }
    
    // SSE Event payloads
    struct ScanProductInfoEvent: Codable {
        let scan_id: String
        let product_info: ScanProductInfo
        let product_info_source: String
        let images: [ScanImage]
    }
    
    struct ScanAnalysisEvent: Codable {
        let analysis_status: String
        let analysis_result: ScanAnalysisResult?
        
        // Note: API uses snake_case throughout (analysis_status, analysis_result, overall_match, overall_analysis, ingredient_analysis)
    }
    
    // Image types in scan response
    enum ScanImage: Codable, Hashable {
        case inventory(InventoryScanImage)
        case user(UserScanImage)
        
        struct InventoryScanImage: Codable, Hashable {
            let type: String  // "inventory"
            let url: String
            var vote: Vote?
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
        let scan_type: String  // "barcode", "photo", or "barcode_plus_photo"
        let barcode: String?
        let state: String  // "fetching_product_info", "processing_images", "analyzing", "done", "error"
        let product_info: ScanProductInfo
        let product_info_source: String?  // "openfoodfacts", "extraction", "enriched"
        var product_info_vote: Vote?
        var analysis_result: ScanAnalysisResult?
        var images: [ScanImage]
        let latest_guidance: String?
        let created_at: String
        let last_activity_at: String
        let error: String?  // Error message when state is "error"

        // Additional fields that may be present in API response but not always used
        let is_favorited: Bool?
        let analysis_id: String?

        enum CodingKeys: String, CodingKey {
            case id
            case scan_type
            case barcode
            case state
            case product_info
            case product_info_source
            case product_info_vote
            case analysis_result
            case images
            case latest_guidance
            case created_at
            case last_activity_at
            case error
            case is_favorited
            case analysis_id
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            scan_type = try container.decode(String.self, forKey: .scan_type)
            barcode = try container.decodeIfPresent(String.self, forKey: .barcode)
            state = try container.decode(String.self, forKey: .state)
            
            // Handle product_info - may be empty object {}
            // Try to decode product_info, if it fails (e.g., empty object), create empty ScanProductInfo
            do {
                let productInfoDecoder = try container.superDecoder(forKey: .product_info)
                product_info = try ScanProductInfo(from: productInfoDecoder)
            } catch let error {
                // If decoding fails (empty object or malformed), create empty ScanProductInfo
                Log.error("SCAN_DECODE", "⚠️ Failed to decode product_info, using empty: \(error)")
                // Create empty ScanProductInfo using the convenience initializer
                product_info = ScanProductInfo(
                    name: nil,
                    brand: nil,
                    ingredients: [],
                    images: nil
                )
            }
            
            product_info_source = try container.decodeIfPresent(String.self, forKey: .product_info_source)
            product_info_vote = try container.decodeIfPresent(Vote.self, forKey: .product_info_vote)
            analysis_result = try container.decodeIfPresent(ScanAnalysisResult.self, forKey: .analysis_result)
            images = try container.decodeIfPresent([ScanImage].self, forKey: .images) ?? []
            latest_guidance = try container.decodeIfPresent(String.self, forKey: .latest_guidance)
            created_at = try container.decode(String.self, forKey: .created_at)
            last_activity_at = try container.decode(String.self, forKey: .last_activity_at)
            error = try container.decodeIfPresent(String.self, forKey: .error)
            is_favorited = try container.decodeIfPresent(Bool.self, forKey: .is_favorited)
            analysis_id = try container.decodeIfPresent(String.self, forKey: .analysis_id)
        }
        
        // Convenience initializer for constructing from SSE events
        init(
            id: String,
            scan_type: String,
            barcode: String?,
            state: String,
            product_info: ScanProductInfo,
            product_info_source: String?,
            product_info_vote: Vote? = nil,
            analysis_result: ScanAnalysisResult?,
            images: [ScanImage],
            latest_guidance: String?,
            created_at: String,
            last_activity_at: String,
            error: String? = nil,
            is_favorited: Bool? = nil,
            analysis_id: String? = nil
        ) {
            self.id = id
            self.scan_type = scan_type
            self.barcode = barcode
            self.state = state
            self.product_info = product_info
            self.product_info_source = product_info_source
            self.product_info_vote = product_info_vote
            self.analysis_result = analysis_result
            self.images = images
            self.latest_guidance = latest_guidance
            self.created_at = created_at
            self.last_activity_at = last_activity_at
            self.error = error
            self.is_favorited = is_favorited
            self.analysis_id = analysis_id
        }
        
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
    
    // Feedback Request
    struct FeedbackRequest: Codable {
        let target: String // "product_info", "product_image", "analysis", "flagged_ingredient", "other"
        let vote: String // "up", "down", "none"
        let scan_id: String?
        let analysis_id: String?
        let image_url: String?
        let ingredient_name: String?
        let comment: String?
    }
    
    struct FeedbackUpdateRequest: Codable {
        let vote: String // "up", "down", "none"
    }
    
    // MARK: - Stats
    
    struct StatsResponse: Codable {
        let avgScans: Int
        let barcodeScansCount: Int
        let matchingStats: MatchingStats
        let weeklyStats: [WeeklyStat]?
    }
    
    struct MatchingStats: Codable {
        let matched: Int
        let unmatched: Int
        let uncertain: Int
    }
    
    struct WeeklyStat: Codable {
        let day: String  // "M", "T", "W", "T", "F", "S", "S"
        let value: Int   // Scan count for that day
        let date: String // ISO date string
    }

    // MARK: - Food Notes Summary

    struct FoodNotesSummaryResponse: Codable {
        let summary: String
        let generatedAt: String
        let isCached: Bool

        enum CodingKeys: String, CodingKey {
            case summary
            case generatedAt = "generated_at"
            case isCached = "is_cached"
        }
    }
}

// MARK: - Scan API Extension Helpers

extension DTO.ScanAnalysisResult {
    func toIngredientRecommendations() -> [DTO.IngredientRecommendation] {
        return ingredient_analysis.map { analysis in
            let safetyRecommendation: DTO.SafetyRecommendation
            switch analysis.match {
            case "unmatched":
                safetyRecommendation = .definitelyUnsafe
            case "uncertain":
                safetyRecommendation = .maybeUnsafe
            default:
                safetyRecommendation = .safe
            }
            
            // Log raw members_affected data for debugging
//            Log.debug("INGREDIENT_ANALYSIS", "ingredient: \(analysis.ingredient), match: \(analysis.match), members_affected: \(analysis.members_affected)")
            
            return DTO.IngredientRecommendation(
                ingredientName: analysis.ingredient,
                safetyRecommendation: safetyRecommendation,
                reasoning: analysis.reasoning,
                preference: analysis.members_affected.joined(separator: ", "),  // Keep for backward compatibility
                memberIdentifiers: analysis.members_affected  // Preserve array of member IDs
            )
        }
    }
}

extension String {
    func toProductRecommendation() -> DTO.ProductRecommendation? {
        switch self.lowercased() {
        case "matched":
            return .match
        case "uncertain":
            return .needsReview
        case "unmatched":
            return .notMatch
        default:
            return nil
        }
    }
}

extension DTO.Scan {
    func toProductRecommendation() -> DTO.ProductRecommendation {
        guard let analysis = analysis_result else {
            return .unknown  // No analysis_result at all
        }

        // When nullable_analysis=true and the user has no food notes, backend may skip LLM
        // analysis entirely and return overall_match = null with an empty ingredient_analysis array.
        if analysis.overall_match == nil && analysis.ingredient_analysis.isEmpty {
            print("[Scan] 🟦 noPreferences inferred for scan_id=\(id) (overall_match=nil, ingredient_analysis empty)")
            return .noPreferences
        }

        if let overallMatch = analysis.overall_match,
           let mapped = overallMatch.toProductRecommendation() {
            return mapped
        }

        return .unknown  // Fallback if string value is unexpected
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
    
    func toProduct() -> DTO.Product {
        // Priority: Use top-level images array if available (supports both inventory and user images)
        var imageLocations: [DTO.ImageLocationInfo] = []
        
        if !images.isEmpty {
            // Convert ScanImage to ImageLocationInfo
            for scanImage in images {
                switch scanImage {
                case .inventory(let img):
                    // Inventory images use URL
                    if let url = URL(string: img.url) {
                        imageLocations.append(.url(url))
                    }
                case .user(let img):
                    // User-uploaded images use storage_path (fetched from "scan-images" bucket)
                    // storage_path format: "SCAN_ID/content_hash.jpg"
                    // Only include processed images with valid storage_path
                    if img.status == "processed", let storagePath = img.storage_path, !storagePath.isEmpty {
                        imageLocations.append(.scanImagePath(storagePath))
                    }
                }
            }
        }
        
        // Fallback: Use product_info.images if no top-level images
        if imageLocations.isEmpty {
            imageLocations = product_info.images?.compactMap { scanImageInfo in
                guard let urlString = scanImageInfo.url,
                      let url = URL(string: urlString) else {
                    return nil
                }
                return .url(url)
            } ?? []
        }
        
        return DTO.Product(
            barcode: barcode,
            brand: product_info.brand,
            name: product_info.name,
            ingredients: product_info.ingredients,
            images: imageLocations,
            claims: product_info.claims
        )
    }
}

// MARK: - ProductRecommendation Display Properties
extension DTO.ProductRecommendation {
    var displayText: String {
        switch self {
        case .match:
            return "Matched"
        case .needsReview:
            return "Uncertain"
        case .notMatch:
            return "Unmatched"
        case .unknown:
            return "Unknown"
        case .noPreferences:
            return "No dietary preferences set"
        }
    }
    
    var iconAssetName: String {
        switch self {
        case .match:
            return "safecircletick"
        case .needsReview:
            return "caution"
        case .notMatch:
            return "unsafe"
        case .unknown:
            return "questionmark.circle"
        case .noPreferences:
            return "questionmark.circle"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .match:
            return [Color(hex: "#9DCF10"), Color(hex: "#6B8E06")]
        case .needsReview:
            return [Color(hex: "#FFC107"), Color(hex: "#FFA000")]
        case .notMatch:
            return [Color(hex: "#FF5252"), Color(hex: "#D32F2F")]
        case .unknown:
            return [Color(hex: "#9E9E9E"), Color(hex: "#757575")]
        case .noPreferences:
            return [Color.grayScale40, Color.grayScale60]
        }
    }
}

// MARK: - Chat API DTOs

extension DTO {
    // Context types (discriminated union based on screen field)
    struct HomeContext: Codable {
        let screen: String // "home"
    }
    
    struct ProductScanContext: Codable {
        let screen: String // "product_scan"
        let scan_id: String // UUID
    }
    
    struct FoodNotesContext: Codable {
        let screen: String // "food_notes"
    }

    struct FeedbackContext: Codable {
        let screen: String // "feedback"
        let feedback_id: String? // UUID, optional for general feedback
    }
    
    // SSE Events (event name: "turn" for thinking/done, "error" for errors)
    struct TurnThinkingEvent: Codable {
        let conversation_id: String // UUID
        let turn_id: String // UUID
        let state: String // "thinking" (const)
    }
    
    struct TurnDoneEvent: Codable {
        let conversation_id: String // UUID
        let turn_id: String // UUID
        let state: String // "done" (const)
        let response: String
    }
    
    struct ChatErrorEvent: Codable {
        let error: String
        let conversation_id: String? // UUID (optional)
        let turn_id: String? // UUID (optional)
    }
    
    // Conversation History
    struct ConversationTurn: Codable {
        let turn_id: String // UUID
        let turn_number: Int
        let user_message: String
        let assistant_response: String? // nullable
        let images: [String] // Array of signed URLs (format: uri, 1hr expiry) - will be ignored in UI
        let created_at: String // ISO 8601 date-time
    }
    
    struct ConversationResponse: Codable {
        let conversation_id: String // UUID
        let turns: [ConversationTurn]
    }
}
