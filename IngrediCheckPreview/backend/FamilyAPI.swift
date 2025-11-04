import Foundation

struct FamilyAPI {
    private static let baseURL = URL(string: "http://127.0.0.1:54321/functions/v1")!
    
    static func makeRequest(
        path: String,
        method: String,
        apiKey: String,
        jwt: String,
        body: [String: Any]? = nil
    ) async throws -> (statusCode: Int, body: String) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
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
        let bodyString = String(data: data, encoding: .utf8) ?? ""
        return (http.statusCode, bodyString)
    }
    
    // POST /ingredicheck/family
    static func createFamily(
        apiKey: String,
        jwt: String,
        name: String,
        selfMember: [String: Any],
        otherMembers: [[String: Any]]? = nil
    ) async throws -> (statusCode: Int, body: String) {
        var body: [String: Any] = [
            "name": name,
            "selfMember": selfMember
        ]
        if let otherMembers = otherMembers {
            body["otherMembers"] = otherMembers
        }
        return try await makeRequest(
            path: "/ingredicheck/family",
            method: "POST",
            apiKey: apiKey,
            jwt: jwt,
            body: body
        )
    }
    
    // GET /ingredicheck/family
    static func getFamily(
        apiKey: String,
        jwt: String
    ) async throws -> (statusCode: Int, body: String) {
        return try await makeRequest(
            path: "/ingredicheck/family",
            method: "GET",
            apiKey: apiKey,
            jwt: jwt,
            body: nil
        )
    }
    
    // POST /ingredicheck/family/invite
    static func createInvite(
        apiKey: String,
        jwt: String,
        memberID: String
    ) async throws -> (statusCode: Int, body: String) {
        let body: [String: Any] = ["memberID": memberID]
        return try await makeRequest(
            path: "/ingredicheck/family/invite",
            method: "POST",
            apiKey: apiKey,
            jwt: jwt,
            body: body
        )
    }
    
    // POST /ingredicheck/family/join
    static func joinFamily(
        apiKey: String,
        jwt: String,
        inviteCode: String
    ) async throws -> (statusCode: Int, body: String) {
        let body: [String: Any] = ["inviteCode": inviteCode]
        return try await makeRequest(
            path: "/ingredicheck/family/join",
            method: "POST",
            apiKey: apiKey,
            jwt: jwt,
            body: body
        )
    }
    
    // POST /ingredicheck/family/leave
    static func leaveFamily(
        apiKey: String,
        jwt: String
    ) async throws -> (statusCode: Int, body: String) {
        return try await makeRequest(
            path: "/ingredicheck/family/leave",
            method: "POST",
            apiKey: apiKey,
            jwt: jwt,
            body: nil
        )
    }
    
    // POST /ingredicheck/family/members
    static func addMember(
        apiKey: String,
        jwt: String,
        member: [String: Any]
    ) async throws -> (statusCode: Int, body: String) {
        return try await makeRequest(
            path: "/ingredicheck/family/members",
            method: "POST",
            apiKey: apiKey,
            jwt: jwt,
            body: member
        )
    }
    
    // PATCH /ingredicheck/family/members/:id
    static func editMember(
        apiKey: String,
        jwt: String,
        memberID: String,
        member: [String: Any]
    ) async throws -> (statusCode: Int, body: String) {
        return try await makeRequest(
            path: "/ingredicheck/family/members/\(memberID)",
            method: "PATCH",
            apiKey: apiKey,
            jwt: jwt,
            body: member
        )
    }
    
    // DELETE /ingredicheck/family/members/:id
    static func deleteMember(
        apiKey: String,
        jwt: String,
        memberID: String
    ) async throws -> (statusCode: Int, body: String) {
        return try await makeRequest(
            path: "/ingredicheck/family/members/\(memberID)",
            method: "DELETE",
            apiKey: apiKey,
            jwt: jwt,
            body: nil
        )
    }
}

