import Foundation
import SwiftUI
import CryptoKit
import Supabase

enum NetworkError: Error {
    case invalidResponse(Int)
    case badUrl
    case decodingError
    case authError
}

@Observable final class WebService {
    
    init() {
        
    }
    
    func fetchProductDetailsFromBarcode(barcode: String) async throws -> DTO.Product {
        
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        let request = SupabaseRequestBuilder(endpoint: .inventory, itemId: barcode)
            .setAuthorization(with: token)
            .setMethod(to: "GET")
            .build()
        
        print(request)

        let (data, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            print("Bad response from server: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        do {
            let product = try JSONDecoder().decode(DTO.Product.self, from: data)
            return product
        } catch {
            print("Failed to decode Product object: \(error)")
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print(responseText)
            throw NetworkError.decodingError
        }
    }
    
    func extractProductDetailsFromLabelImages(
        clientActivityId: String,
        labelImages: [IngredientLabel]
    ) async throws -> DTO.Product {

        struct ImageInfo: Codable {
            let imageFileHash: String
            let imageOCRText: String
        }

        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        let imageFileHash = try await uploadImage(image: labelImages[0].image)
        let labelInfo: [ImageInfo] = [ImageInfo(
            imageFileHash: imageFileHash,
            imageOCRText: labelImages.first!.imageOCRText
        )]

        let jsonData = try JSONEncoder().encode(labelInfo)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        let request = SupabaseRequestBuilder(endpoint: .extract)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .setFormData(name: "clientActivityId", value: clientActivityId)
            .setFormData(name: "productImages", value: jsonString)
            .build()
        
        print(request)

        let (data, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            print("Bad response from server: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        do {
            let product = try JSONDecoder().decode(DTO.Product.self, from: data)
            print(product)
            return product
        } catch {
            print("Failed to decode Product object: \(error)")
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print(responseText)
            throw NetworkError.decodingError
        }
    }
    
    func fetchIngredientRecommendations(
        clientActivityId: String,
        userPreferenceText: String,
        barcode: String? = nil
    ) async throws -> [DTO.IngredientRecommendation] {
        
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }
        
        var requestBuilder = SupabaseRequestBuilder(endpoint: .analyze)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .setFormData(name: "clientActivityId", value: clientActivityId)
            .setFormData(name: "userPreferenceText", value: userPreferenceText)
        
        if let barcode = barcode {
            requestBuilder = requestBuilder.setFormData(name: "barcode", value: barcode)
        }

        let request = requestBuilder.build()

        print("Fetching recommendations")
        let (data, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            print("Bad response from server: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }

        do {
            let ingredientRecommendations = try JSONDecoder().decode([DTO.IngredientRecommendation].self, from: data)
            print(ingredientRecommendations)
            return ingredientRecommendations
        } catch {
            print("Failed to decode IngredientRecommendation array: \(error)")
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print(responseText)
            throw NetworkError.decodingError
        }
    }
    
    func rateAnalysis(
        clientActivityId: String,
        rating: Int
    ) async throws {
        
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }
        
        let request = SupabaseRequestBuilder(endpoint: .analyze_rate)
            .setAuthorization(with: token)
            .setMethod(to: "PATCH")
            .setFormData(name: "clientActivityId", value: clientActivityId)
            .setFormData(name: "rating", value: String(rating))
            .build()

        print("Rating analysis: \(rating)")
        let (_, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            print("Bad response from server: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
    }
    
    func uploadImage(image: UIImage) async throws -> String {
        
        let imageData = image.jpegData(compressionQuality: 1.0)!
        let imageFileName = SHA256.hash(data: imageData).compactMap { String(format: "%02x", $0) }.joined()

        try await supabaseClient.storage.from("productimages").upload(
            path: imageFileName,
            file: imageData
        )

        return imageFileName
    }
}
