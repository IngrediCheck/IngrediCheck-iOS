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
        
        Log.debug("FamilyAPI", "🔵 makeRequest - Method: \(method), Path: \(path)")
        Log.debug("FamilyAPI", "📡 URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        // Configure timeouts to prevent connection loss
        request.timeoutInterval = 30.0 // 30 seconds timeout
        
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                let bodyData = try JSONSerialization.data(withJSONObject: body)
                request.httpBody = bodyData
                Log.debug("FamilyAPI", "📦 Request body size: \(bodyData.count) bytes")
            } catch {
                Log.debug("FamilyAPI", "❌ Failed to serialize request body: \(error)")
                throw error
            }
        }
        
        Log.debug("FamilyAPI", "🔑 Headers - apikey: \(apiKey.prefix(10))..., Authorization: Bearer \(jwt.prefix(20))...")
        
        // Retry logic for connection loss errors
        var lastError: Error?
        let maxRetries = 3
        
        for attempt in 1...maxRetries {
            do {
                Log.debug("FamilyAPI", "⏳ Sending request (attempt \(attempt)/\(maxRetries))...")
                let (data, response) = try await URLSession.shared.data(for: request)
                lastError = nil // Clear error on success
            
            guard let http = response as? HTTPURLResponse else {
                Log.debug("FamilyAPI", "❌ Invalid response type: \(type(of: response))")
                throw URLError(.badServerResponse)
            }
            
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            Log.debug("FamilyAPI", "✅ Response received - Status: \(http.statusCode), Body length: \(bodyString.count) chars")
            
            if http.statusCode >= 400 {
                Log.debug("FamilyAPI", "❌ Error response - Status: \(http.statusCode)")
                Log.debug("FamilyAPI", "📄 Error body: \(bodyString.prefix(500))")
            } else {
                Log.debug("FamilyAPI", "✅ Success response - Status: \(http.statusCode)")
                if !bodyString.isEmpty {
                    Log.debug("FamilyAPI", "📄 Response body (first 500 chars): \(bodyString.prefix(500))")
                }
            }
            
                return (http.statusCode, bodyString)
            } catch {
                lastError = error
                Log.debug("FamilyAPI", "❌ Network error on attempt \(attempt): \(error.localizedDescription)")
                
                if let urlError = error as? URLError {
                    Log.debug("FamilyAPI", "❌ URLError code: \(urlError.code.rawValue), description: \(urlError.localizedDescription)")
                    
                    // Retry on connection loss errors (-1005, -1001 timeout, -1009 no internet)
                    let retryableErrors: [URLError.Code] = [.networkConnectionLost, .timedOut, .notConnectedToInternet]
                    
                    if retryableErrors.contains(urlError.code) && attempt < maxRetries {
                        let delay = UInt64(1_000_000_000 * UInt64(attempt)) // 1s, 2s, 3s
                        Log.debug("FamilyAPI", "🔄 Retrying after \(attempt) second(s)...")
                        try? await Task.sleep(nanoseconds: delay)
                        continue // Retry the request
                    }
                }
                
                // If not retryable or max retries reached, throw the error
                if attempt == maxRetries {
                    Log.debug("FamilyAPI", "❌ Max retries reached, throwing error")
                    throw error
                }
            }
        }
        
        // This should never be reached, but just in case
        if let error = lastError {
            throw error
        }
        
        throw URLError(.unknown)
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
        Log.debug("FamilyAPI", "🔵 createFamily called")
        Log.debug("FamilyAPI", "📝 Parameters - name: \(name), selfMember: \(selfMember), otherMembers count: \(otherMembers?.count ?? 0)")
        
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
            Log.debug("FamilyAPI", "📦 createFamily request body: \(jsonString)")
        } else {
            Log.debug("FamilyAPI", "⚠️ Failed to serialize request body to JSON string")
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

    // POST /ingredicheck/family/personal
    static func createPersonalFamily(
        baseURL: String,
        apiKey: String,
        jwt: String,
        name: String,
        memberID: String
    ) async throws -> (statusCode: Int, body: String) {
        let body: [String: Any] = [
            "name": name,
            "memberID": memberID
        ]
        return try await makeRequest(
            baseURL: baseURL,
            path: "family/personal",
            method: "POST",
            apiKey: apiKey,
            jwt: jwt,
            body: body
        )
    }
}

