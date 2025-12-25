
import Foundation

enum SafeEatsEndpoint: String {
    case deleteme = "deleteme"
    case ingredicheck_analyze_stream = "analyze-stream"
    case ingredicheck_ping = "ping"
    case feedback = "feedback"
    case memoji = "memoji"
    case history = "history"
    // Scan API endpoints
    case scan_barcode = "v2/scan/barcode"
    case scan_image = "v2/scan/%@/image"
    case scan_get = "v2/scan/%@"
    case scan_history = "v2/scan/history"
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
    case family_member_food_notes = "family/members/%@/food-notes"
}

class SupabaseRequestBuilder {

    private var request: URLRequest
    private var httpBody = Data()
    private var hasMultipartFormData: Bool = false
    private let boundary = UUID().uuidString
    private let endpoint: SafeEatsEndpoint
    private let url: URL
    
    /// Returns the appropriate base URL based on the endpoint type
    private static func baseURL(for endpoint: SafeEatsEndpoint) -> String {
        switch endpoint {
        case .scan_barcode, .scan_image, .scan_get, .scan_history:
            return Config.flyDevAPIBase
        default:
            return Config.supabaseFunctionsURLBase
        }
    }

    init(endpoint: SafeEatsEndpoint) {
        self.endpoint = endpoint
        let baseURL = Self.baseURL(for: endpoint)
        self.url = URL(string: (baseURL + endpoint.rawValue))!
        self.request = URLRequest(url: self.url)
        print("[SupabaseRequestBuilder] init endpoint=\(endpoint.rawValue) baseURL=\(baseURL) url=\(self.url.absoluteString)")
    }
    
    init(endpoint: SafeEatsEndpoint, itemId: String, subItemId: String? = nil) {
        self.endpoint = endpoint
        let baseURL = Self.baseURL(for: endpoint)
        
        func formattedUrlString() -> String {
            let urlFormat = baseURL + endpoint.rawValue
            if let subItemId = subItemId {
                return String(format: urlFormat, itemId, subItemId)
            } else {
                return String(format: urlFormat, itemId)
            }
        }

        self.url = URL(string: formattedUrlString())!
        self.request = URLRequest(url: self.url)
        print("[SupabaseRequestBuilder] init endpoint=\(endpoint.rawValue) baseURL=\(baseURL) url=\(self.url.absoluteString)")
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
        print("[SupabaseRequestBuilder] setMethod endpoint=\(endpoint.rawValue) method=\(method)")
        return self
    }
    
    func setJsonBody(to body: Data) -> SupabaseRequestBuilder {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        print("[SupabaseRequestBuilder] setJsonBody endpoint=\(endpoint.rawValue) bodySize=\(body.count) bytes")
        if let jsonString = String(data: body, encoding: .utf8) {
            print("[SupabaseRequestBuilder] setJsonBody body=\(jsonString)")
        }
        return self
    }

    func setAuthorization(with token: String) -> SupabaseRequestBuilder {
        let authHeaderString = "Bearer \(token)"
        request.setValue(authHeaderString, forHTTPHeaderField: "Authorization")
        print("[SupabaseRequestBuilder] setAuthorization endpoint=\(endpoint.rawValue) tokenPrefix=\(String(token.prefix(20)))...")
        print("[SupabaseRequestBuilder] setAuthorization FULL Authorization header: \(authHeaderString)")
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
        // Only set API key for Supabase endpoints, not Fly.dev endpoints
        let baseURL = Self.baseURL(for: endpoint)
        if baseURL == Config.supabaseFunctionsURLBase {
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
        
        print("[SupabaseRequestBuilder] build() endpoint=\(endpoint.rawValue) method=\(request.httpMethod ?? "nil") url=\(request.url?.absoluteString ?? "nil")")
        print("[SupabaseRequestBuilder] build() headers=\(request.allHTTPHeaderFields ?? [:])")
        if let authHeader = request.value(forHTTPHeaderField: "Authorization") {
            print("[SupabaseRequestBuilder] build() FULL Authorization header value: \(authHeader)")
        }
        if hasMultipartFormData {
            print("[SupabaseRequestBuilder] build() multipart bodySize=\(request.httpBody?.count ?? 0)")
        } else if request.httpBody != nil {
            print("[SupabaseRequestBuilder] build() json bodySize=\(request.httpBody?.count ?? 0)")
        }

        return request
    }
}
