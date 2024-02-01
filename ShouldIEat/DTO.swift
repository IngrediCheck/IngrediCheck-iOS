//
//  DTO.swift
//  ShouldIEat
//
//  Created by sanket patel on 2/1/24.
//

import Foundation

class DTO {

    struct ImageInfo: Codable, Hashable {
        let url: URL
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
    
    struct Product: Codable, Hashable {
        let brand: String?
        let name: String
        let ingredients: [Ingredient]
        let images: [ImageInfo]
    }
}
