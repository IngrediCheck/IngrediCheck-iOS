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
            print("[FamilyService] decodeFamily error: cannot convert body to UTF-8 data")
            throw NetworkError.decodingError
        }
        do {
            return try JSONDecoder().decode(Family.self, from: data)
        } catch {
            print("[FamilyService] decodeFamily JSON error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("[FamilyService] decodeFamily dataCorrupted: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("[FamilyService] decodeFamily keyNotFound: \(key.stringValue) in \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("[FamilyService] decodeFamily typeMismatch: \(type) in \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("[FamilyService] decodeFamily valueNotFound: \(type) in \(context.debugDescription)")
                @unknown default:
                    print("[FamilyService] decodeFamily unknown decoding error")
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
        print("[FamilyService] createFamily request name=\(name), self=\(selfMember.name) (id=\(selfMember.id)), others=\(otherNames)")
        let jwt = try await currentJWT()
        
        func memberDict(_ member: FamilyMember) -> [String: Any] {
            var dict: [String: Any] = [
                "id": member.id.uuidString,
                "name": member.name,
                "color": member.color
            ]
            if let imageFileHash = member.imageFileHash {
                dict["imageFileHash"] = imageFileHash
            }
            return dict
        }
        
        let selfMemberDict = memberDict(selfMember)
        let otherMembersDict = otherMembers?.map(memberDict)
        
        print("[FamilyService] createFamily URL base=\(baseURL), full path=\(baseURL)family")
        print("[FamilyService] createFamily request body: name=\(name), selfMember=\(selfMemberDict), otherMembers=\(otherMembersDict?.count ?? 0) items")
        
        let result = try await FamilyAPI.createFamily(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt,
            name: name,
            selfMember: selfMemberDict,
            otherMembers: otherMembersDict
        )
        
        print("[FamilyService] createFamily response status=\(result.statusCode), body length=\(result.body.count)")
        if !result.body.isEmpty {
            print("[FamilyService] createFamily response body (first 1000 chars): \(String(result.body.prefix(1000)))")
        } else {
            print("[FamilyService] createFamily response body: (empty)")
        }
        
        guard (200 ..< 300).contains(result.statusCode) else {
            print("[FamilyService] createFamily bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
        
        // Some endpoints might return 204 No Content, but createFamily should return the created family
        guard !result.body.isEmpty else {
            print("[FamilyService] createFamily error: empty response body for status \(result.statusCode)")
            // If we got 201/200 but empty body, try fetching the family instead
            if result.statusCode == 200 || result.statusCode == 201 {
                print("[FamilyService] createFamily attempting to fetch family after empty response")
                return try await fetchFamily()
            }
            throw NetworkError.decodingError
        }
        
        let family = try decodeFamily(from: result.body)
        print("[FamilyService] createFamily decoded family name=\(family.name), members=\(family.selfMember.name) + \(family.otherMembers.map { $0.name })")
        return family
    }
    
    func fetchFamily() async throws -> Family {
        print("[FamilyService] fetchFamily request")
        let jwt = try await currentJWT()
        
        let result = try await FamilyAPI.getFamily(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt
        )
        
        guard result.statusCode == 200 else {
            print("[FamilyService] fetchFamily bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
        
        let family = try decodeFamily(from: result.body)
        print("[FamilyService] fetchFamily decoded family name=\(family.name)")
        print("[FamilyService] fetchFamily selfMember.imageFileHash=\(family.selfMember.imageFileHash ?? "nil")")
        for (index, member) in family.otherMembers.enumerated() {
            print("[FamilyService] fetchFamily otherMembers[\(index)].imageFileHash=\(member.imageFileHash ?? "nil")")
        }
        return family
    }
    
    func createInvite(for memberId: UUID) async throws -> String {
        print("[FamilyService] createInvite for memberId=\(memberId)")
        let jwt = try await currentJWT()
        
        let result = try await FamilyAPI.createInvite(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt,
            memberID: memberId.uuidString
        )
        
        guard result.statusCode == 201 else {
            print("[FamilyService] createInvite bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
        
        let code = try decodeInviteCode(from: result.body)
        print("[FamilyService] createInvite decoded code=\(code)")
        return code
    }
    
    func joinFamily(inviteCode: String) async throws -> Family {
        print("[FamilyService] joinFamily request code=\(inviteCode)")
        let jwt = try await currentJWT()
        
        let result = try await FamilyAPI.joinFamily(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt,
            inviteCode: inviteCode
        )
        
        guard result.statusCode == 201 else {
            print("[FamilyService] joinFamily bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
        
        let family = try decodeFamily(from: result.body)
        print("[FamilyService] joinFamily decoded family name=\(family.name)")
        return family
    }
    
    func leaveFamily() async throws {
        print("[FamilyService] leaveFamily request")
        let jwt = try await currentJWT()
        
        let result = try await FamilyAPI.leaveFamily(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt
        )
        
        guard result.statusCode == 200 else {
            print("[FamilyService] leaveFamily bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
    }
    
    func addMember(_ member: FamilyMember) async throws -> Family {
        print("[FamilyService] addMember request id=\(member.id)")
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
            print("[FamilyService] addMember bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
        
        let family = try decodeFamily(from: result.body)
        print("[FamilyService] addMember decoded family name=\(family.name)")
        return family
    }
    
    func editMember(_ member: FamilyMember) async throws -> Family {
        print("[FamilyService] editMember request id=\(member.id)")
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
            print("[FamilyService] editMember bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
        
        let family = try decodeFamily(from: result.body)
        print("[FamilyService] editMember decoded family name=\(family.name)")
        print("[FamilyService] editMember selfMember.imageFileHash=\(family.selfMember.imageFileHash ?? "nil")")
        for (index, member) in family.otherMembers.enumerated() {
            print("[FamilyService] editMember otherMembers[\(index)].name=\(member.name), imageFileHash=\(member.imageFileHash ?? "nil")")
        }
        return family
    }
    
    func deleteMember(id: UUID) async throws -> Family {
        print("[FamilyService] deleteMember request id=\(id)")
        let jwt = try await currentJWT()
        
        let result = try await FamilyAPI.deleteMember(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt,
            memberID: id.uuidString
        )
        
        guard result.statusCode == 200 else {
            print("[FamilyService] deleteMember bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
        
        let family = try decodeFamily(from: result.body)
        print("[FamilyService] deleteMember decoded family name=\(family.name)")
        return family
    }

    func createPersonalFamily(name: String, memberID: String) async throws -> Family {
        print("[FamilyService] createPersonalFamily request name=\(name), memberID=\(memberID)")
        let jwt = try await currentJWT()
        
        let result = try await FamilyAPI.createPersonalFamily(
            baseURL: baseURL,
            apiKey: apiKey,
            jwt: jwt,
            name: name,
            memberID: memberID
        )
        
        guard (200 ..< 300).contains(result.statusCode) else {
            print("[FamilyService] createPersonalFamily bad status: \(result.statusCode), body=\(result.body)")
            throw NetworkError.invalidResponse(result.statusCode)
        }
        
        let family = try decodeFamily(from: result.body)
        print("[FamilyService] createPersonalFamily decoded family name=\(family.name)")
        return family
    }
}


