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

    private let webService: WebService
    private let staticUserPreferenceText: String

    // Simple in-memory cache so we don't re-hit the network when the user
    // swipes back to a barcode card that's already been analyzed.
    private static var resultCache: [String: BarcodeScanAnalysisResult] = [:]

    init(webService: WebService, userPreferenceText: String = "None") {
        self.webService = webService
        self.staticUserPreferenceText = userPreferenceText
    }

    static func cachedResult(for barcode: String) -> BarcodeScanAnalysisResult? {
        resultCache[barcode]
    }

    static func storeResult(_ result: BarcodeScanAnalysisResult) {
        resultCache[result.barcode] = result
    }
    
    static func clearResult(for barcode: String) {
        resultCache.removeValue(forKey: barcode)
    }

    func analyze(barcode: String) async -> BarcodeScanAnalysisResult {
        let clientActivityId = UUID().uuidString

        var product: DTO.Product?
        var ingredientRecommendations: [DTO.IngredientRecommendation]?
        var notFound = false
        var errorMessage: String?

        do {
            try await webService.streamUnifiedAnalysis(
                input: .barcode(barcode),
                clientActivityId: clientActivityId,
                userPreferenceText: staticUserPreferenceText,
                onProduct: { value in
                    product = value
                },
                onAnalysis: { recommendations in
                    ingredientRecommendations = recommendations
                },
                onError: { streamError in
                    if streamError.statusCode == 404 {
                        notFound = true
                    } else {
                        errorMessage = streamError.message
                    }
                }
            )
        } catch NetworkError.notFound(_) {
            notFound = true
        } catch {
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
        }

        let matchStatus: DTO.ProductRecommendation?
        if let product, let ingredientRecommendations {
            matchStatus = product.calculateMatch(ingredientRecommendations: ingredientRecommendations)
        } else {
            matchStatus = nil
        }

        let result = BarcodeScanAnalysisResult(
            product: product,
            ingredientRecommendations: ingredientRecommendations,
            matchStatus: matchStatus,
            notFound: notFound,
            errorMessage: errorMessage,
            barcode: barcode,
            clientActivityId: clientActivityId
        )

        // Cache the result for this barcode for the lifetime of the app
        // session so subsequent visits to the same card can reuse it.
        Self.storeResult(result)

        return result
    }
}

