//
//  AIMemojiService.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 06/11/25.
//

import UIKit

struct MemojiRequest: Encodable {
    let familyType: String
    let gesture: String
    let hair: String
    let skinTone: String
    let accessories: [String]
    let background: String
    let size: String
    let model: String
    let subscriptionTier: String
}

private struct MemojiResponse: Decodable {
    let success: Bool
    let cached: Bool?
    let imageUrl: String?
}

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
    guard let image = UIImage(data: pngData) else {
        throw AIMemojiError.missingImage
    }

    return image
}

// Backward compatibility stub: uses a default request
func generateMemojiImage() async throws -> UIImage {
    let defaultRequest = MemojiRequest(
        familyType: "father",
        gesture: "wave",
        hair: "long",
        skinTone: "light",
        accessories: ["sunglass"],
        background: "transparent",
        size: "1024x1024",
        model: "gpt-image-1",
        subscriptionTier: "monthly_basic"
    )
    return try await generateMemojiImage(requestBody: defaultRequest)
}
