//
//  AIMemojiService.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 06/11/25.
//

import UIKit

enum AIMemojiError: LocalizedError {
    case notAuthenticated
    case invalidResponse(String)
    case missingImage

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to generate a memoji."
        case .invalidResponse(let message):
            return "Memoji request failed: \(message)"
        case .missingImage:
            return "Memoji response did not include an image."
        }
    }
}

func generateMemojiImage(requestBody: MemojiRequest) async throws -> UIImage {
    guard let token = try? await supabaseClient.auth.session.accessToken else {
        throw AIMemojiError.notAuthenticated
    }

    let bodyData = try JSONEncoder().encode(requestBody)
    
    // DEBUG: Print the JSON being sent to API
    if let jsonString = String(data: bodyData, encoding: .utf8) {
        print("[Memoji API] Request JSON: \(jsonString)")
        
        // Also pretty print for better readability
        if let jsonObject = try? JSONSerialization.jsonObject(with: bodyData, options: []),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print("[Memoji API] Request JSON (pretty):\n\(prettyString)")
        }
    }

    let request = SupabaseRequestBuilder(endpoint: .memoji)
        .setAuthorization(with: token)
        .setMethod(to: "POST")
        .setJsonBody(to: bodyData)
        .build()

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw AIMemojiError.invalidResponse("No HTTP response.")
    }

    guard httpResponse.statusCode == 200 else {
        let message = String(data: data, encoding: .utf8) ?? "status \(httpResponse.statusCode)"
        throw AIMemojiError.invalidResponse(message)
    }

    let decoded = try JSONDecoder().decode(MemojiResponse.self, from: data)
    guard let urlString = decoded.imageUrl, let url = URL(string: urlString) else {
        throw AIMemojiError.missingImage
    }

    let (pngData, _) = try await URLSession.shared.data(from: url)
    print("[AIMemojiService] generateMemojiImage: Before UIImage(data:) - Thread.isMainThread=\(Thread.isMainThread)")
    // CRITICAL: UIImage(data:) must be called on main thread - UIImage operations are not thread-safe
    let image = await MainActor.run {
        let isMainThread = Thread.isMainThread
        print("[AIMemojiService] generateMemojiImage: Inside MainActor.run - Thread.isMainThread=\(isMainThread)")
        let img = UIImage(data: pngData)
        print("[AIMemojiService] generateMemojiImage: UIImage(data:) created - image=\(img != nil ? "✅" : "❌")")
        return img
    }
    print("[AIMemojiService] generateMemojiImage: After MainActor.run - Thread.isMainThread=\(Thread.isMainThread)")
    guard let image = image else {
        throw AIMemojiError.missingImage
    }

    return image
}

