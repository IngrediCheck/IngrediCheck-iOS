
import Foundation

enum SafeEatsEndpoint: String {
    case inventory = "inventory/%@"
    case analyze = "analyze"
    case extract = "extract"
    case feedback = "feedback"
    case history = "history"
    case list_items = "lists/%@"
    case list_items_item = "lists/%@/%@"
    case preference_lists_default = "preferencelists/default"
    case preference_lists_default_items = "preferencelists/default/%@"
}

class SupabaseRequestBuilder {

    private var request: URLRequest
    private var httpBody = Data()
    private var hasMultipartFormData: Bool = false
    private let boundary = UUID().uuidString
    private let endpoint: SafeEatsEndpoint
    private let url: URL

    init(endpoint: SafeEatsEndpoint) {
        self.endpoint = endpoint
        self.url = URL(string: (Config.supabaseFunctionsURLBase + endpoint.rawValue))!
        self.request = URLRequest(url: self.url)
    }
    
    init(endpoint: SafeEatsEndpoint, itemId: String, subItemId: String? = nil) {

        func formattedUrlString() -> String {
            let urlFormat = Config.supabaseFunctionsURLBase + endpoint.rawValue
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
        request.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
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
            print("Size of Supabase \(endpoint.rawValue) request body is: \(request.httpBody?.count ?? 0)")
        }

        return request
    }
}
