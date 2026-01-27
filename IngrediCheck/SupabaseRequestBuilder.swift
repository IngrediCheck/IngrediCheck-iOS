
import Foundation
import os

enum SafeEatsEndpoint: String {
    case deleteme = "deleteme"
    case ingredicheck_analyze_stream = "analyze-stream"
    case ingredicheck_ping = "ping"
    case feedback = "feedback"
    case memoji = "memoji"
    case history = "history"
//    case scan_favorite = "scan/%@/favorite"
    case list_items = "lists/%@"
    case list_items_item = "lists/%@/%@"
    case preference_lists_grandfathered = "preferencelists/grandfathered"
    case preference_lists_default = "preferencelists/default"
    case preference_lists_default_items = "preferencelists/default/%@"
    case devices_register = "devices/register"
    case devices_mark_internal = "devices/mark-internal"
    case devices_is_internal = "devices/%@/is-internal"
    case family_food_notes = "family/food-notes"
    case family_food_notes_all = "family/food-notes/all"
    case family_food_notes_summary = "family/food-notes/summary"
    case family_member_food_notes = "family/members/%@/food-notes"
    
    // Scan API endpoints
    case scan_barcode = "v2/scan/barcode"
    case scan_image = "v2/scan/%@/image"
    case scan_get = "v2/scan/%@"
    case scan_history = "v2/scan/history"
    case scan_favorite = "v2/scan/%@/favorite"  // POST to toggle favorite
    case scan_reanalyze = "v2/scan/%@/reanalyze"   // POST to re-analyze scan
    case scan_feedback = "v2/scan/feedback"        // POST to submit feedback
    case scan_feedback_update = "v2/scan/feedback/%@" // PATCH to update feedback
    case stats_v2 = "v2/stats"                // GET to fetch stats
    
    // Chat API endpoints
    case chat_send = "v2/chat"
    case chat_get = "v2/chat/%@"
}

class SupabaseRequestBuilder {

    private var request: URLRequest
    private var httpBody = Data()
    private var hasMultipartFormData: Bool = false
    private let boundary = UUID().uuidString
    private let endpoint: SafeEatsEndpoint
    private let url: URL

    private static func baseURL(for endpoint: SafeEatsEndpoint) -> String {
        switch endpoint {
        case .scan_barcode, .scan_image, .scan_reanalyze, .family_food_notes_summary, .chat_send, .chat_get:
            return Config.flyIOBaseURL + "/"
        case .scan_history, .scan_get, .scan_favorite, .scan_feedback, .scan_feedback_update, .stats_v2:
            return Config.supabaseFunctionsURLBase
        default:
            return Config.supabaseFunctionsURLBase
        }
    }

    init(endpoint: SafeEatsEndpoint) {
        self.endpoint = endpoint
        let baseURL = Self.baseURL(for: endpoint)
        self.url = URL(string: (baseURL + endpoint.rawValue))!
        self.request = URLRequest(url: self.url)
    }
    
    init(endpoint: SafeEatsEndpoint, itemId: String, subItemId: String? = nil) {

        func formattedUrlString() -> String {
            let baseURL = Self.baseURL(for: endpoint)
            let urlFormat = baseURL + endpoint.rawValue
            if let subItemId = subItemId {
                return String(format: urlFormat, itemId, subItemId)
            } else {
                return String(format: urlFormat, itemId)
            }
        }

        self.endpoint = endpoint
        self.url = URL(string: formattedUrlString())!
        self.request = URLRequest(url: self.url)
    }
    
    func setQueryItems(queryItems: [URLQueryItem]) -> SupabaseRequestBuilder {
        if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = queryItems
            // This is a bit hacky. Updating url after the request was created with a different url
            request.url = components.url!
        }
        return self
    }

    func setMethod(to method: String) -> SupabaseRequestBuilder {
        request.httpMethod = method
        return self
    }
    
    func setJsonBody(to body: Data) -> SupabaseRequestBuilder {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return self
    }

    func setAuthorization(with token: String) -> SupabaseRequestBuilder {
        let authHeaderString = "Bearer \(token)"
        request.setValue(authHeaderString, forHTTPHeaderField: "Authorization")
        return self
    }

    func setFormData(name: String, value: String) -> SupabaseRequestBuilder {

        httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
        httpBody.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        httpBody.append("\(value)".data(using: .utf8)!)
        httpBody.append("\r\n".data(using: .utf8)!)

        hasMultipartFormData = true
        return self
    }
    
    func setFormData(name: String, value: Data, contentType: String) -> SupabaseRequestBuilder {
        
        httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
        httpBody.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(name)\"\r\n".data(using: .utf8)!)
        httpBody.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        httpBody.append(value)
        httpBody.append("\r\n".data(using: .utf8)!)

        hasMultipartFormData = true
        return self
    }

    private func setAPIKey() {
        // Only set API key for Supabase endpoints, not for scan/chat API endpoints
        // Scan and Chat APIs use Bearer token authentication only
        let bearerAuthEndpoints: [SafeEatsEndpoint] = [.scan_barcode, .scan_image, .scan_get, .scan_favorite, .scan_reanalyze, .scan_feedback, .scan_feedback_update, .stats_v2, .family_food_notes_summary, .chat_send, .chat_get]
        if !bearerAuthEndpoints.contains(endpoint) {
            request.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        }
    }
    
    private func finishMultipartFormDataIfNeeded() {
        if hasMultipartFormData {
            httpBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
            self.request.httpBody = httpBody
            self.request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        }
    }
    
    func build() -> URLRequest {

        setAPIKey()
        finishMultipartFormDataIfNeeded()
        
        if hasMultipartFormData {
            Log.debug("SupabaseRequestBuilder", "Size of Supabase \(endpoint.rawValue) request body is: \(request.httpBody?.count ?? 0)")
        }

        return request
    }
}
