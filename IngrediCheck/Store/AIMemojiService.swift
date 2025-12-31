//
//  AIMemojiService.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 06/11/25.
//

import UIKit

/// Container for a generated memoji image and its storage location.
struct GeneratedMemoji {
    /// The rendered memoji image as a transparent PNG.
    let image: UIImage
    /// The storage path inside the `memoji-images` bucket, e.g. `2025/01/<hash>.png`.
    /// Used as `imageFileHash` when assigning avatars so we can load directly from Supabase
    /// without re-uploading the PNG.
    let storagePath: String
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

/// Extract the internal storage path from a memoji public URL.
/// - Parameter urlString: Full public URL returned by the memoji API.
/// - Returns: Path inside the `memoji-images` bucket, e.g. `2025/01/<hash>.png`.
///            If the URL doesn't match the expected pattern (e.g. test mode),
///            falls back to returning the input string.
private func extractMemojiStoragePath(from urlString: String) -> String {
    // Expected format:
    // https://<project>.supabase.co/storage/v1/object/public/memoji-images/2025/01/<hash>.png
    if let range = urlString.range(of: "/memoji-images/") {
        let path = urlString[range.upperBound...]
        return String(path)
    }
    // Fallback for test URLs like test://memoji/<hash>.png or unexpected formats.
    return urlString
}

/// Calls the memoji edge function, returning both the rendered image and its
/// storage path inside the `memoji-images` bucket.
func generateMemojiImage(requestBody: MemojiRequest) async throws -> GeneratedMemoji {
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

    let storagePath = extractMemojiStoragePath(from: urlString)
    print("[AIMemojiService] generateMemojiImage: Using storagePath=\(storagePath)")

    return GeneratedMemoji(image: image, storagePath: storagePath)
}

