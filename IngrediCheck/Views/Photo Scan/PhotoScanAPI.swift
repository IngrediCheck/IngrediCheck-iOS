import Foundation
import UIKit

struct PhotoScanAPI {
    
    // MARK: - Generic Request Helper
    static func makeRequest(
        baseURL: String,
        path: String,
        method: String,
        apiKey: String,
        jwt: String,
        body: [String: Any]? = nil,
        queryParams: [String: String]? = nil
    ) async throws -> (statusCode: Int, body: Data) {
        var urlString = baseURL.hasSuffix("/") ? baseURL + path : baseURL + "/" + path
        
        if let queryParams = queryParams, !queryParams.isEmpty {
            var components = URLComponents(string: urlString)
            components?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
            if let url = components?.url {
                urlString = url.absoluteString
            }
        }
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        return (http.statusCode, data)
    }
    
    // MARK: - Multipart Request Helper
    static func makeMultipartRequest(
        baseURL: String,
        path: String,
        method: String,
        apiKey: String,
        jwt: String,
        imageData: Data,
        boundary: String = UUID().uuidString
    ) async throws -> (statusCode: Int, body: Data) {
        let urlString = baseURL.hasSuffix("/") ? baseURL + path : baseURL + "/" + path
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        return (http.statusCode, data)
    }
    
    // MARK: - API Endpoints
    
    // 1. Submit Image (Upload Photo)
    // Endpoint: POST /ingredicheck/v2/scan/{scan_id}/image
    static func submitImage(
        baseURL: String,
        apiKey: String,
        jwt: String,
        scanId: String,
        image: UIImage
    ) async throws -> SubmitImageResponse {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        let (statusCode, data) = try await makeMultipartRequest(
            baseURL: baseURL,
            path: "ingredicheck/v2/scan/\(scanId)/image",
            method: "POST",
            apiKey: apiKey,
            jwt: jwt,
            imageData: imageData
        )
        
        guard statusCode == 200 else {
            print("Submit Image Failed: \(statusCode) - \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(SubmitImageResponse.self, from: data)
    }
    
    // 2. Get Scan Details (Polling)
    // Endpoint: GET /ingredicheck/v2/scan/{scan_id}
    static func getScanDetails(
        baseURL: String,
        apiKey: String,
        jwt: String,
        scanId: String
    ) async throws -> ScanDetailsResponse {
        let (statusCode, data) = try await makeRequest(
            baseURL: baseURL,
            path: "ingredicheck/v2/scan/\(scanId)",
            method: "GET",
            apiKey: apiKey,
            jwt: jwt
        )
        
        guard statusCode == 200 else {
            print("Get Scan Details Failed: \(statusCode) - \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        
        // Custom decoding to handle ingredient variations if needed, 
        // but for now relying on the standard decoder with our flexible model
        return try JSONDecoder().decode(ScanDetailsResponse.self, from: data)
    }
    
    // 3. Scan History
    // Endpoint: GET /ingredicheck/v2/scan/history?limit=20&offset=0
    static func getScanHistory(
        baseURL: String,
        apiKey: String,
        jwt: String,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> ScanHistoryResponse {
        let (statusCode, data) = try await makeRequest(
            baseURL: baseURL,
            path: "ingredicheck/v2/scan/history",
            method: "GET",
            apiKey: apiKey,
            jwt: jwt,
            queryParams: [
                "limit": "\(limit)",
                "offset": "\(offset)"
            ]
        )
        
        guard statusCode == 200 else {
            print("Get Scan History Failed: \(statusCode) - \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(ScanHistoryResponse.self, from: data)
    }
}
