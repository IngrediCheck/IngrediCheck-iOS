//
//  ChatContextBuilder.swift
//  IngrediCheck
//
//  Created to build chat context based on current screen state
//

import Foundation
import SwiftUI

class ChatContextBuilder {
    // Build context objects (returns specific context type, not union)
    static func buildHomeContext() -> DTO.HomeContext {
        return DTO.HomeContext(screen: "home")
    }
    
    static func buildProductScanContext(scanId: String) -> DTO.ProductScanContext {
        return DTO.ProductScanContext(screen: "product_scan", scan_id: scanId)
    }
    
    static func buildFoodNotesContext() -> DTO.FoodNotesContext {
        return DTO.FoodNotesContext(screen: "food_notes")
    }

    static func buildFeedbackContext(feedbackId: String? = nil) -> DTO.FeedbackContext {
        return DTO.FeedbackContext(screen: "feedback", feedback_id: feedbackId)
    }
    
    // Encode context to JSON string for API
    static func encodeContext(_ context: any Codable) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(context)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "ChatContextBuilder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode context to JSON string"])
        }
        return jsonString
    }
}
