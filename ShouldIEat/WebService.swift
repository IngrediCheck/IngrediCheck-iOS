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
        
        guard let product = try? JSONDecoder().decode(DTO.Product.self, from: data) else {
            print("Failed to decode Product object")
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print(responseText)
            throw NetworkError.decodingError
        }
        
        return product
    }
}
