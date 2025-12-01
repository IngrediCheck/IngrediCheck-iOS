//
//  AIMemojiService.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 06/11/25.
//

import UIKit

struct SignResponse: Decodable { let timestamp: String; let signature: String }
struct GenerateCached: Decodable { let success: Bool; let imageUrl: String? }
struct ImageData: Decodable { let b64_json: String? }
struct GenerateFresh: Decodable { let data: [ImageData]? }

func memojiRequestBody() -> [String: Any] {
    return [
        "userId": UUID().uuidString,
        "subscriptionTier": "monthly_basic",
        "familyType": "mother",
        "gesture": "heart", // examples: "wave", "heart-hands", "thumbs-up", "peace-sign", "pointing"
        "hair": "long",
        "skinTone": "light",
        "background": "auto", // or "auto"
        "size": "1024x1024",
        "model": "gpt-image-1"
    ]
}

func postJSON<T: Decodable>(_ url: URL, body: [String: Any], headers: [String: String] = [:]) async throws -> T {
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
    req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
    let (data, resp) = try await URLSession.shared.data(for: req)
    guard (resp as? HTTPURLResponse)?.statusCode ?? 500 < 300 else {
        throw NSError(domain: "memoji", code: 1, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Error"])
    }
    return try JSONDecoder().decode(T.self, from: data)
}

func generateMemojiImage(baseURL: String) async throws -> UIImage {
    // 1) Sign
    let signURL = URL(string: "\(baseURL)/api/sign")!
    let body = memojiRequestBody()
    let signResp: SignResponse = try await postJSON(signURL, body: ["body": body])

    // 2) Generate
    let genURL = URL(string: "\(baseURL)/api/generate-memoji")!
    var headers = [String: String]()
    headers["X-Timestamp"] = signResp.timestamp
    headers["X-Signature"] = signResp.signature
    headers["X-Client-Version"] = "ios-1.0.0"

    // Try parse as cached (imageUrl)
    if let cached: GenerateCached = try? await postJSON(genURL, body: body, headers: headers),
       let urlStr = cached.imageUrl, let url = URL(string: urlStr) {
        let (pngData, _) = try await URLSession.shared.data(from: url)
        if let img = UIImage(data: pngData) { return img }
    }

    // Else parse fresh base64
    let fresh: GenerateFresh = try await postJSON(genURL, body: body, headers: headers)
    if let b64 = fresh.data?.first?.b64_json,
       let imgData = Data(base64Encoded: b64),
       let img = UIImage(data: imgData) {
        return img
    }

    throw NSError(domain: "memoji", code: 2, userInfo: [NSLocalizedDescriptionKey: "No image in response"])
}
