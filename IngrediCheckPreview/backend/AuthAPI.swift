import Foundation

struct AuthAPI {
    private static let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
    private static let baseURL = URL(string: "http://127.0.0.1:54321")!

    static func signupEmptyBody() async throws -> (statusCode: Int, body: String) {
        var request = URLRequest(url: baseURL.appendingPathComponent("/auth/v1/signup"))
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

    static func signupAnonymous() async throws -> (statusCode: Int, body: String) {
        var components = URLComponents(url: baseURL.appendingPathComponent("/auth/v1/signup"), resolvingAgainstBaseURL: false)!
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


