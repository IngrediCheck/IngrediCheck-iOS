//
//  Store.swift
//  ShouldIEat
//
//  Created by sanket patel on 2/1/24.
//

import Foundation

enum NetworkError: Error {
    case invalidResponse(Int)
    case badUrl
    case decodingError
    case authError
}

@Observable final class WebService {
    
    init() {
        
    }
    
    func fetchProduct(barcode: String) async throws -> DTO.Product {
        
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        let request = SupabaseRequestBuilder(endpoint: .inventory, itemId: barcode)
            .setAuthorization(with: token)
            .setMethod(to: "GET")
            .build()

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
    
    func fetchIngredientRecommendations(
        clientActivityId: String,
        barcode: String,
        userPreferenceText: String
    ) async throws -> [DTO.IngredientRecommendation] {
        
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }
        
        let request = SupabaseRequestBuilder(endpoint: .analyze)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .setFormData(name: "clientActivityId", value: clientActivityId)
            .setFormData(name: "barcode", value: barcode)
            .setFormData(name: "userPreferenceText", value: userPreferenceText)
            .build()

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
}
