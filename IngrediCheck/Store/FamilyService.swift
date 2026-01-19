import Foundation

final class FamilyService {
    
    private let baseURL: String
    private let apiKey: String
    
    init(
        baseURL: String = Config.supabaseFunctionsURLBase,
        apiKey: String = Config.supabaseKey
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
    
    // MARK: - Helpers
    
    private func currentJWT() async throws -> String {
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }
        return token
    }
    
    private func decodeFamily(from body: String) throws -> Family {
        guard let data = body.data(using: .utf8) else {
            Log.debug("FamilyService", "decodeFamily error: cannot convert body to UTF-8 data")
            throw NetworkError.decodingError
        }
        do {
            return try JSONDecoder().decode(Family.self, from: data)
        } catch {
            Log.debug("FamilyService", "decodeFamily JSON error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    Log.debug("FamilyService", "decodeFamily dataCorrupted: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    Log.debug("FamilyService", "decodeFamily keyNotFound: \(key.stringValue) in \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    Log.debug("FamilyService", "decodeFamily typeMismatch: \(type) in \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    Log.debug("FamilyService", "decodeFamily valueNotFound: \(type) in \(context.debugDescription)")
                @unknown default:
                    Log.debug("FamilyService", "decodeFamily unknown decoding error")
                }
            }
            throw error
        }
    }
    
    private func decodeInviteCode(from body: String) throws -> String {
        guard let data = body.data(using: .utf8) else {
            throw NetworkError.decodingError
        }
        let response = try JSONDecoder().decode(InviteResponse.self, from: data)
        return response.inviteCode
    }

    // MARK: - Public API
    
    func createFamily(
        name: String,
        selfMember: FamilyMember,
        otherMembers: [FamilyMember]?
    ) async throws -> Family {
        let otherNames = otherMembers?.map { $0.name } ?? []
        Log.debug("FamilyService", "🔵 createFamily called")
        Log.debug("FamilyService", "📝 Parameters - name: \(name), self: \(selfMember.name) (id: \(selfMember.id)), others: \(otherNames)")
        
        do {
            let jwt = try await currentJWT()
            Log.debug("FamilyService", "✅ JWT obtained (length: \(jwt.count) chars)")
            
            func memberDict(_ member: FamilyMember) -> [String: Any] {
                var dict: [String: Any] = [
                    "id": member.id.uuidString,
                    "name": member.name,
                    "color": member.color
                ]
                if let imageFileHash = member.imageFileHash {
                    dict["imageFileHash"] = imageFileHash
                    Log.debug("FamilyService", "📸 Member \(member.name) has imageFileHash: \(imageFileHash)")
                }
                return dict
            }
            
            let selfMemberDict = memberDict(selfMember)
            let otherMembersDict = otherMembers?.map(memberDict)
            
            Log.debug("FamilyService", "📡 API Configuration - baseURL: \(baseURL), full path: \(baseURL)family")
            Log.debug("FamilyService", "📦 Request - name: \(name), selfMember keys: \(selfMemberDict.keys), otherMembers count: \(otherMembersDict?.count ?? 0)")
            
            let result = try await FamilyAPI.createFamily(
                baseURL: baseURL,
                apiKey: apiKey,
                jwt: jwt,
                name: name,
                selfMember: selfMemberDict,
                otherMembers: otherMembersDict
            )
            
            Log.debug("FamilyService", "📥 Response received - status: \(result.statusCode), body length: \(result.body.count) chars")
            
            if !result.body.isEmpty {
                Log.debug("FamilyService", "📄 Response body (first 1000 chars): \(String(result.body.prefix(1000)))")
            } else {
                Log.debug("FamilyService", "⚠️ Response body is empty")
            }
            
            guard (200 ..< 300).contains(result.statusCode) else {
                Log.debug("FamilyService", "❌ Error response - status: \(result.statusCode)")
                Log.debug("FamilyService", "📄 Error body: \(result.body)")
                throw NetworkError.invalidResponse(result.statusCode)
            }

            let family = try decodeFamily(from: result.body)
            Log.debug("FamilyService", "✅ Successfully decoded family - name: \(family.name), selfMember: \(family.selfMember.name), otherMembers: \(family.otherMembers.map { $0.name })")
            return family
        } catch {
            Log.debug("FamilyService", "❌ createFamily failed with error: \(error)")
            if let networkError = error as? NetworkError {
                Log.debug("FamilyService", "❌ NetworkError type: \(networkError)")
            } else if let urlError = error as? URLError {
                Log.debug("FamilyService", "❌ URLError code: \(urlError.code.rawValue), description: \(urlError.localizedDescription)")
            }
            throw error
        }
    }

    func updateFamily(name: String) async throws -> Family {
        Log.debug("FamilyService", "🔵 updateFamily called")
        Log.debug("FamilyService", "📝 Parameters - name: \(name)")

        let jwt = try await currentJWT()
        Log.debug("FamilyService", "✅ JWT obtained (length: \(jwt.count) chars)")

        let result = try await FamilyAPI.updateFamily(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt,
            name: name
        )

        Log.debug("FamilyService", "📥 Response received - status: \(result.statusCode), body length: \(result.body.count) chars")

        if !result.body.isEmpty {
            Log.debug("FamilyService", "📄 Response body (first 1000 chars): \(String(result.body.prefix(1000)))")
        } else {
            Log.debug("FamilyService", "⚠️ Response body is empty")
        }

        guard (200 ..< 300).contains(result.statusCode) else {
            Log.debug("FamilyService", "❌ Error response - status: \(result.statusCode)")
            Log.debug("FamilyService", "📄 Error body: \(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }

        let family = try decodeFamily(from: result.body)
        Log.debug("FamilyService", "✅ Successfully decoded family - name: \(family.name), selfMember: \(family.selfMember.name), otherMembers: \(family.otherMembers.map { $0.name })")
        return family
    }
    
    func fetchFamily() async throws -> Family {
        Log.debug("FamilyService", "fetchFamily request")
        let jwt = try await currentJWT()
        
        let result = try await FamilyAPI.getFamily(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt
        )
        
        guard result.statusCode == 200 else {
            Log.debug("FamilyService", "fetchFamily bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
        
        let family = try decodeFamily(from: result.body)
        Log.debug("FamilyService", "fetchFamily decoded family name=\(family.name)")
        Log.debug("FamilyService", "fetchFamily selfMember.imageFileHash=\(family.selfMember.imageFileHash ?? "nil")")
        for (index, member) in family.otherMembers.enumerated() {
            Log.debug("FamilyService", "fetchFamily otherMembers[\(index)].imageFileHash=\(member.imageFileHash ?? "nil")")
        }
        return family
    }
    
    func createInvite(for memberId: UUID) async throws -> String {
        Log.debug("FamilyService", "createInvite for memberId=\(memberId)")
        let jwt = try await currentJWT()
        
        let result = try await FamilyAPI.createInvite(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt,
            memberID: memberId.uuidString
        )
        
        guard result.statusCode == 201 else {
            Log.debug("FamilyService", "createInvite bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
        
        // Handle empty response body - retry the createInvite request since we need the invite code
        if result.body.isEmpty {
            print("[FamilyService] ⚠️ Empty response body for createInvite, retrying request")
            // Add initial delay to ensure backend has finished processing
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Retry the createInvite request up to 2 times (to avoid creating duplicate invites)
            var lastError: Error?
            for attempt in 1...2 {
                do {
                    print("[FamilyService] 🔄 Retry attempt \(attempt)/2 for createInvite")
                    let retryResult = try await FamilyAPI.createInvite(
                        baseURL: baseURL,
                        apiKey: apiKey,
                        jwt: jwt,
                        memberID: memberId.uuidString
                    )
                    
                    guard retryResult.statusCode == 201 else {
                        print("[FamilyService] ❌ Retry createInvite bad status: \(retryResult.statusCode)")
                        throw NetworkError.invalidResponse(retryResult.statusCode)
                    }
                    
                    if !retryResult.body.isEmpty {
                        let code = try decodeInviteCode(from: retryResult.body)
                        print("[FamilyService] ✅ Successfully got invite code on retry: \(code)")
                        return code
                    }
                    
                    // If still empty, continue to next retry
                    print("[FamilyService] ⚠️ Retry attempt \(attempt) still returned empty body")
                    if attempt < 2 {
                        let delay = UInt64(1_000_000_000 * UInt64(attempt)) // 1s, 2s
                        try? await Task.sleep(nanoseconds: delay)
                    }
                } catch {
                    lastError = error
                    print("[FamilyService] ⚠️ Retry attempt \(attempt) failed: \(error.localizedDescription)")
                    if attempt < 2 {
                        let delay = UInt64(1_000_000_000 * UInt64(attempt)) // 1s, 2s
                        try? await Task.sleep(nanoseconds: delay)
                    }
                }
            }
            
            // If all retries failed, throw a user-friendly error
            print("[FamilyService] ❌ All retry attempts failed for createInvite")
            throw NetworkError.decodingError
        }
        
        let code = try decodeInviteCode(from: result.body)
        Log.debug("FamilyService", "createInvite decoded code=\(code)")
        return code
    }
    
    func joinFamily(inviteCode: String) async throws -> Family {
        Log.debug("FamilyService", "joinFamily request code=\(inviteCode)")
        let jwt = try await currentJWT()
        
        let result = try await FamilyAPI.joinFamily(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt,
            inviteCode: inviteCode
        )
        
        guard result.statusCode == 201 else {
            Log.debug("FamilyService", "joinFamily bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }

        let family = try decodeFamily(from: result.body)
        Log.debug("FamilyService", "joinFamily decoded family name=\(family.name)")
        return family
    }

    func leaveFamily() async throws {
        Log.debug("FamilyService", "leaveFamily request")
        let jwt = try await currentJWT()
        
        let result = try await FamilyAPI.leaveFamily(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt
        )
        
        guard result.statusCode == 200 else {
            Log.debug("FamilyService", "leaveFamily bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
    }
    
    func addMember(_ member: FamilyMember) async throws -> Family {
        Log.debug("FamilyService", "addMember request id=\(member.id)")
        let jwt = try await currentJWT()
        
        var body: [String: Any] = [
            "id": member.id.uuidString,
            "name": member.name,
            "color": member.color
        ]
        if let imageFileHash = member.imageFileHash {
            body["imageFileHash"] = imageFileHash
        }
        
        let result = try await FamilyAPI.addMember(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt,
            member: body
        )
        
        guard result.statusCode == 201 else {
            Log.debug("FamilyService", "addMember bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }

        let family = try decodeFamily(from: result.body)
        Log.debug("FamilyService", "addMember decoded family name=\(family.name)")
        return family
    }

    func editMember(_ member: FamilyMember) async throws -> Family {
        Log.debug("FamilyService", "editMember request id=\(member.id)")
        let jwt = try await currentJWT()
        
        var body: [String: Any] = [
            "name": member.name,
            "color": member.color
        ]
        if let imageFileHash = member.imageFileHash {
            body["imageFileHash"] = imageFileHash
        }
        
        let result = try await FamilyAPI.editMember(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt,
            memberID: member.id.uuidString,
            member: body
        )
        
        guard result.statusCode == 200 else {
            Log.debug("FamilyService", "editMember bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
        
        let family = try decodeFamily(from: result.body)
        Log.debug("FamilyService", "editMember decoded family name=\(family.name)")
        Log.debug("FamilyService", "editMember selfMember.imageFileHash=\(family.selfMember.imageFileHash ?? "nil")")
        for (index, member) in family.otherMembers.enumerated() {
            Log.debug("FamilyService", "editMember otherMembers[\(index)].name=\(member.name), imageFileHash=\(member.imageFileHash ?? "nil")")
        }
        return family
    }
    
    func deleteMember(id: UUID) async throws -> Family {
        Log.debug("FamilyService", "deleteMember request id=\(id)")
        let jwt = try await currentJWT()
        
        let result = try await FamilyAPI.deleteMember(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt,
            memberID: id.uuidString
        )
        
        guard result.statusCode == 200 else {
            Log.debug("FamilyService", "deleteMember bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
        
        let family = try decodeFamily(from: result.body)
        Log.debug("FamilyService", "deleteMember decoded family name=\(family.name)")
        return family
    }

    func createPersonalFamily(name: String, memberID: String) async throws -> Family {
        Log.debug("FamilyService", "createPersonalFamily request name=\(name), memberID=\(memberID)")
        let jwt = try await currentJWT()
        
        let result = try await FamilyAPI.createPersonalFamily(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt,
            name: name,
            memberID: memberID
        )
        
        guard (200 ..< 300).contains(result.statusCode) else {
            Log.debug("FamilyService", "createPersonalFamily bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
        
        let family = try decodeFamily(from: result.body)
        Log.debug("FamilyService", "createPersonalFamily decoded family name=\(family.name)")
        return family
    }
}


