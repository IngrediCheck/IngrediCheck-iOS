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
    
    struct HistoryItem: Codable, Hashable, Equatable {
        let created_at: String
        let client_activity_id: String
        let barcode: String?
        let brand: String?
        let name: String?
        let ingredients: [Ingredient]
        let images: [ImageLocationInfo]
        let ingredient_recommendations: [IngredientRecommendation]
    }
    
    struct Product: Codable, Hashable {
        let barcode: String?
        let brand: String?
        let name: String?
        let ingredients: [Ingredient]
        let images: [ImageLocationInfo]

        private func productHasIngredient(ingredientName: String) -> Bool {
            return ingredients.contains { i in
                if i.name.caseInsensitiveCompare(ingredientName) == .orderedSame {
                    return true
                }
                return i.ingredients.contains { i2 in
                    if i2.name.caseInsensitiveCompare(ingredientName) == .orderedSame {
                        return true
                    }
                    return i2.ingredients.contains { i3 in
                        return i3.name.caseInsensitiveCompare(ingredientName) == .orderedSame
                    }
                }
            }
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
        
        private var ingredientsListAsString: String {
            return ingredients.map { ingredient in
                ingredientToString(ingredient)
            }
            .joined(separator: ", ")
            .capitalized
        }

        func decoratedIngredientsList(
            ingredientRecommendations: [IngredientRecommendation]?
        ) -> AttributedString {
            var attributedString = AttributedString(ingredientsListAsString)
            
            guard let ingredientRecommendations = ingredientRecommendations else {
                return attributedString
            }
            
            for recommendation in ingredientRecommendations {
                let color: Color
                switch recommendation.safetyRecommendation {
                case .maybeUnsafe:
                    color = .orange
                case .definitelyUnsafe:
                    color = .red
                }
                
                // Note: I could not find a straightforward Api to find all matches of
                // a substring in an AttributedString, so using this convoluted approach.
                var tempAttributedString = AttributedString()
                while let range = attributedString.range(of: recommendation.ingredientName, options: .caseInsensitive) {
                    let prefix = attributedString[..<range.lowerBound]
                    var ingredientName = attributedString[range]
                    ingredientName.foregroundColor = color
                    tempAttributedString.append(prefix)
                    tempAttributedString.append(ingredientName)
                    attributedString = AttributedString(attributedString[range.upperBound...])
                }
                tempAttributedString.append(attributedString)
                attributedString = tempAttributedString
            }
            
            return attributedString
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
                    }
                }
            }
            return result
        }
    }
    
    enum SafetyRecommendation: String, Codable {
        case maybeUnsafe = "MaybeUnsafe"
        case definitelyUnsafe = "DefinitelyUnsafe"
    }
    
    struct IngredientRecommendation: Codable, Equatable, Hashable {
        let ingredientName: String
        let safetyRecommendation: SafetyRecommendation
        let reasoning: String
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
}
