//
//  AIMemojiService.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 06/11/25.
//

import UIKit
import os

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
        Log.debug("Memoji API", "Request JSON: \(jsonString)")
        
        // Also pretty print for better readability
        if let jsonObject = try? JSONSerialization.jsonObject(with: bodyData, options: []),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            Log.debug("Memoji API", "Request JSON (pretty):\n\(prettyString)")
        }
    }

    var request = SupabaseRequestBuilder(endpoint: .memoji)
        .setAuthorization(with: token)
        .setMethod(to: "POST")
        .setJsonBody(to: bodyData)
        .build()
    
    // Configure timeout to prevent connection loss
    request.timeoutInterval = 60.0 // 60 seconds for memoji generation (longer than family API)
    
    Log.debug("AIMemojiService", "🔵 Sending memoji generation request...")
    
    // Retry logic for connection loss errors
    var lastError: Error?
    let maxRetries = 3
    var data: Data?
    var response: URLResponse?
    
    for attempt in 1...maxRetries {
        do {
            Log.debug("AIMemojiService", "⏳ Request attempt \(attempt)/\(maxRetries)...")
            let result = try await URLSession.shared.data(for: request)
            data = result.0
            response = result.1
            lastError = nil // Clear error on success
            break // Exit retry loop on success
        } catch {
            lastError = error
            Log.error("AIMemojiService", "❌ Network error on attempt \(attempt): \(error.localizedDescription)")
            
            if let urlError = error as? URLError {
                Log.error("AIMemojiService", "❌ URLError code: \(urlError.code.rawValue), description: \(urlError.localizedDescription)")
                
                // Retry on connection loss errors (-1005, -1001 timeout, -1009 no internet)
                let retryableErrors: [URLError.Code] = [.networkConnectionLost, .timedOut, .notConnectedToInternet]
                
                if retryableErrors.contains(urlError.code) && attempt < maxRetries {
                    let delay = UInt64(1_000_000_000 * UInt64(attempt)) // 1s, 2s, 3s
                    Log.debug("AIMemojiService", "🔄 Retrying after \(attempt) second(s)...")
                    try? await Task.sleep(nanoseconds: delay)
                    continue // Retry the request
                }
            }
            
            // If not retryable or max retries reached, throw the error
            if attempt == maxRetries {
                Log.error("AIMemojiService", "❌ Max retries reached, throwing error")
                throw error
            }
        }
    }
    
    // Ensure we have data and response
    guard let responseData = data, let urlResponse = response else {
        if let error = lastError {
            throw error
        }
        Log.error("AIMemojiService", "❌ No data or response received")
        throw AIMemojiError.invalidResponse("No response received.")
    }

    guard let httpResponse = urlResponse as? HTTPURLResponse else {
        Log.error("AIMemojiService", "❌ No HTTP Response received")
        throw AIMemojiError.invalidResponse("No HTTP response.")
    }

    Log.debug("AIMemojiService", "✅ Response received - Status: \(httpResponse.statusCode), Body length: \(responseData.count) bytes")

    guard httpResponse.statusCode == 200 else {
        let message = String(data: responseData, encoding: .utf8) ?? "status \(httpResponse.statusCode)"
        Log.error("AIMemojiService", "❌ Request failed with message: \(message)")
        
        // Try to parse error details from backend response
        if let errorData = try? JSONDecoder().decode(MemojiErrorResponse.self, from: responseData) {
            let errorMessage = errorData.error.message
            let errorDetails = errorData.error.details ?? ""
            Log.error("AIMemojiService", "❌ Backend error message: \(errorMessage)")
            if !errorDetails.isEmpty {
                Log.error("AIMemojiService", "❌ Backend error details: \(errorDetails)")
            }
            // Use the detailed error message if available
            let fullMessage = errorDetails.isEmpty ? errorMessage : "\(errorMessage): \(errorDetails)"
            throw AIMemojiError.invalidResponse(fullMessage)
        }
        
        throw AIMemojiError.invalidResponse(message)
    }

    let decoded: MemojiResponse
    do {
        decoded = try JSONDecoder().decode(MemojiResponse.self, from: responseData)
        Log.debug("AIMemojiService", "✅ Successfully decoded MemojiResponse")
    } catch {
        let rawDataString = String(data: responseData, encoding: .utf8) ?? "Unable to convert data to string"
        Log.error("AIMemojiService", "❌ Decoding failed: \(error.localizedDescription)")
        Log.error("AIMemojiService", "❌ Raw Data that failed to decode: \(rawDataString)")
        throw error
    }

    guard let urlString = decoded.imageUrl, let url = URL(string: urlString) else {
        Log.error("AIMemojiService", "❌ decoded.imageUrl is NIL or invalid")
        throw AIMemojiError.missingImage
    }

    Log.debug("AIMemojiService", "ℹ️ Image URL: \(urlString)")

    // Download image with timeout configuration
    var imageRequest = URLRequest(url: url)
    imageRequest.timeoutInterval = 30.0 // 30 seconds for image download
    Log.debug("AIMemojiService", "🔵 Downloading memoji image...")
    
    let (pngData, _) = try await URLSession.shared.data(for: imageRequest)
    Log.debug("AIMemojiService", "✅ Downloaded PNG Data size: \(pngData.count) bytes")
    Log.debug("AIMemojiService", "generateMemojiImage: Before UIImage(data:) - Thread.isMainThread=\(Thread.isMainThread)")
    // CRITICAL: UIImage(data:) must be called on main thread - UIImage operations are not thread-safe
    let image = await MainActor.run {
        let isMainThread = Thread.isMainThread
        Log.debug("AIMemojiService", "generateMemojiImage: Inside MainActor.run - Thread.isMainThread=\(isMainThread)")
        let img = UIImage(data: pngData)
        Log.debug("AIMemojiService", "generateMemojiImage: UIImage(data:) created - image=\(img != nil ? ")✅" : "❌")")
        return img
    }
    Log.debug("AIMemojiService", "generateMemojiImage: After MainActor.run - Thread.isMainThread=\(Thread.isMainThread)")
    guard let image = image else {
        throw AIMemojiError.missingImage
    }

    let storagePath = extractMemojiStoragePath(from: urlString)
    Log.debug("AIMemojiService", "generateMemojiImage: Using storagePath=\(storagePath)")

    return GeneratedMemoji(image: image, storagePath: storagePath)
}

