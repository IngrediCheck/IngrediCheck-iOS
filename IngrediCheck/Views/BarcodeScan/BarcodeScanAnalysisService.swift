import Foundation

@MainActor
struct BarcodeScanAnalysisResult {
    let product: DTO.Product?
    let ingredientRecommendations: [DTO.IngredientRecommendation]?
    let matchStatus: DTO.ProductRecommendation?
    let notFound: Bool
    let errorMessage: String?
    let barcode: String
    let clientActivityId: String
}

@MainActor
final class BarcodeScanAnalysisService {

    // Simple in-memory cache so we don't re-hit the network when the user
    // swipes back to a barcode card that's already been analyzed.
    private static var resultCache: [String: BarcodeScanAnalysisResult] = [:]

    static func cachedResult(for barcode: String) -> BarcodeScanAnalysisResult? {
        resultCache[barcode]
    }

    static func storeResult(_ result: BarcodeScanAnalysisResult) {
        resultCache[result.barcode] = result
    }
    
    static func clearResult(for barcode: String) {
        resultCache.removeValue(forKey: barcode)
    }
}

