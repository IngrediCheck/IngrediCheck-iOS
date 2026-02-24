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
    
    // Infer context from current navigation state
    // This is a helper that can be called from views to determine context
    static func contextFromCurrentScreen(
        coordinator: AppNavigationCoordinator,
        currentScan: DTO.Scan? = nil,
        analysisId: String? = nil,
        ingredientName: String? = nil
    ) -> any Codable {
        // Default to home context
        // Views should pass specific context when they know the screen type
        // This is a fallback for general cases
        return buildHomeContext()
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
