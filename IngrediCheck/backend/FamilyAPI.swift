import Foundation

struct FamilyAPI {
    static func makeRequest(
        baseURL: String,
        path: String,
        method: String,
        apiKey: String,
        jwt: String,
        body: [String: Any]? = nil
    ) async throws -> (statusCode: Int, body: String) {
        let urlString = baseURL.hasSuffix("/") ? baseURL + path : baseURL + "/" + path
        let url = urlString.hasPrefix("http") ? URL(string: urlString)! : URL(string: "http://\(urlString)")!
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
        let bodyString = String(data: data, encoding: .utf8) ?? ""
        return (http.statusCode, bodyString)
    }
    
    // POST /ingredicheck/family
    static func createFamily(
        baseURL: String,
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
        
        // Log request body for debugging
        if let jsonData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[FamilyAPI] createFamily request body: \(jsonString)")
        }
        
        return try await makeRequest(
            baseURL: baseURL,
            path: "family",
            method: "POST",
            apiKey: apiKey,
            jwt: jwt,
            body: body
        )
    }
    
    // GET /ingredicheck/family
    static func getFamily(
        baseURL: String,
        apiKey: String,
        jwt: String
    ) async throws -> (statusCode: Int, body: String) {
        return try await makeRequest(
            baseURL: baseURL,
            path: "family",
            method: "GET",
            apiKey: apiKey,
            jwt: jwt,
            body: nil
        )
    }
    
    // POST /ingredicheck/family/invite
    static func createInvite(
        baseURL: String,
        apiKey: String,
        jwt: String,
        memberID: String
    ) async throws -> (statusCode: Int, body: String) {
        let body: [String: Any] = ["memberID": memberID]
        return try await makeRequest(
            baseURL: baseURL,
            path: "family/invite",
            method: "POST",
            apiKey: apiKey,
            jwt: jwt,
            body: body
        )
    }
    
    // POST /ingredicheck/family/join
    static func joinFamily(
        baseURL: String,
        apiKey: String,
        jwt: String,
        inviteCode: String
    ) async throws -> (statusCode: Int, body: String) {
        let body: [String: Any] = ["inviteCode": inviteCode]
        return try await makeRequest(
            baseURL: baseURL,
            path: "family/join",
            method: "POST",
            apiKey: apiKey,
            jwt: jwt,
            body: body
        )
    }
    
    // POST /ingredicheck/family/leave
    static func leaveFamily(
        baseURL: String,
        apiKey: String,
        jwt: String
    ) async throws -> (statusCode: Int, body: String) {
        return try await makeRequest(
            baseURL: baseURL,
            path: "family/leave",
            method: "POST",
            apiKey: apiKey,
            jwt: jwt,
            body: nil
        )
    }
    
    // POST /ingredicheck/family/members
    static func addMember(
        baseURL: String,
        apiKey: String,
        jwt: String,
        member: [String: Any]
    ) async throws -> (statusCode: Int, body: String) {
        return try await makeRequest(
            baseURL: baseURL,
            path: "family/members",
            method: "POST",
            apiKey: apiKey,
            jwt: jwt,
            body: member
        )
    }
    
    // PATCH /ingredicheck/family/members/:id
    static func editMember(
        baseURL: String,
        apiKey: String,
        jwt: String,
        memberID: String,
        member: [String: Any]
    ) async throws -> (statusCode: Int, body: String) {
        return try await makeRequest(
            baseURL: baseURL,
            path: "family/members/\(memberID)",
            method: "PATCH",
            apiKey: apiKey,
            jwt: jwt,
            body: member
        )
    }
    
    // DELETE /ingredicheck/family/members/:id
    static func deleteMember(
        baseURL: String,
        apiKey: String,
        jwt: String,
        memberID: String
    ) async throws -> (statusCode: Int, body: String) {
        return try await makeRequest(
            baseURL: baseURL,
            path: "family/members/\(memberID)",
            method: "DELETE",
            apiKey: apiKey,
            jwt: jwt,
            body: nil
        )
    }
}

