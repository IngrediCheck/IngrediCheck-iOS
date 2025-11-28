import Foundation

struct AuthAPI {
    private static let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

    static func signupEmptyBody(baseURL: String) async throws -> (statusCode: Int, body: String) {
        let urlString = baseURL.hasSuffix("/") ? baseURL + "auth/v1/signup" : baseURL + "/auth/v1/signup"
        let url = urlString.hasPrefix("http") ? URL(string: urlString)! : URL(string: "http://\(urlString)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        // Explicitly send an empty body
        request.httpBody = Data()

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        let bodyString = String(data: data, encoding: .utf8) ?? ""
        return (http.statusCode, bodyString)
    }

    static func signupAnonymous(baseURL: String) async throws -> (statusCode: Int, body: String) {
        let urlString = baseURL.hasSuffix("/") ? baseURL + "auth/v1/signup" : baseURL + "/auth/v1/signup"
        let url = urlString.hasPrefix("http") ? URL(string: urlString)! : URL(string: "http://\(urlString)")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "provider", value: "anonymous")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Send empty JSON object as body
        request.httpBody = Data("{}".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        let bodyString = String(data: data, encoding: .utf8) ?? ""
        return (http.statusCode, bodyString)
    }
}


