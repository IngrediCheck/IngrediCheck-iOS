import Foundation
import Observation

@Observable
@MainActor
final class FamilyStore {
    
    private let service: FamilyService
    
    // MARK: - State
    
    private(set) var family: Family?
    private(set) var isLoading = false
    private(set) var isJoining = false
    private(set) var isInviting = false
    private(set) var errorMessage: String?

    // Temporary in-memory builder used by the preview onboarding flow
    // before the family is actually created on the backend.
    private(set) var pendingSelfMember: FamilyMember?
    private(set) var pendingOtherMembers: [FamilyMember] = []
    
    /// Currently selected member in the family preferences UI.
    /// `nil` means "Everyone" (family-level).
    var selectedMemberId: UUID? = nil
    
    /// Target member for avatar assignment from the MeetYourAvatar flow.
    /// When non-nil, this is the member whose avatar should be updated.
    var avatarTargetMemberId: UUID? = nil
    
    init(service: FamilyService = FamilyService()) {
        self.service = service
    }
    
    // MARK: - Pending members (preview flow helpers)
    
    /// Generates a random pastel hex color for a new family member.
    private func randomColor() -> String {
        // Curated palette of soft pastel colors
        let pastelColors = [
            "#FFB3BA", // Pastel Pink
            "#FFDFBA", // Pastel Peach
            "#FFFFBA", // Pastel Yellow
            "#BAFFC9", // Pastel Mint
            "#BAE1FF", // Pastel Blue
            "#E0BBE4", // Pastel Lavender
            "#FFCCCB", // Light Pink
            "#B4E4FF", // Sky Blue
            "#C7CEEA", // Periwinkle
            "#F0E6FF", // Lavender
            "#FFE5B4", // Peach
            "#E8F5E9", // Light Green
            "#FFF9C4", // Light Yellow
            "#F8BBD0", // Pink
            "#B2EBF2", // Cyan
            "#D1C4E9", // Light Purple
            "#FFE0B2", // Apricot
            "#C5E1A5", // Light Lime
            "#BBDEFB", // Light Blue
            "#F1F8E9"  // Very Light Green
        ]
        return pastelColors.randomElement() ?? "#FFB3BA"
    }
    
    /// Set the primary (self) member from the onboarding flow.
    func setPendingSelfMember(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("[FamilyStore] Ignoring empty self member name")
            return
        }
        let color = randomColor()
        print("[FamilyStore] Setting pending self member name: \(trimmed), color: \(color)")
        
        pendingSelfMember = FamilyMember(
            id: UUID(),
            name: trimmed,
            color: color,
            joined: true,
            imageFileHash: nil
        )
    }
    
    /// Add an additional family member to the pending list.
    func addPendingOtherMember(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("[FamilyStore] Ignoring empty other member name")
            return
        }
        let color = randomColor()
        print("[FamilyStore] Adding pending other member: \(trimmed), color: \(color)")
        
        let member = FamilyMember(
            id: UUID(),
            name: trimmed,
            color: color,
            joined: false,
            imageFileHash: nil
        )
        pendingOtherMembers.append(member)
    }
    
    /// Creates the family on the backend using any pending members, if present.
    func createFamilyFromPendingIfNeeded() async {
        guard let selfMember = pendingSelfMember else {
            print("[FamilyStore] createFamilyFromPendingIfNeeded: no pending self member, skipping")
            return
        }
        
        let others = pendingOtherMembers
        let familyName = "\(selfMember.name)'s Family"
        print("[FamilyStore] Creating family from pending. name=\(familyName), self=\(selfMember.name), others=\(others.map { $0.name })")
        
        await createOrUpdateFamily(
            name: familyName,
            selfMember: selfMember,
            otherMembers: others
        )
        
        // Clear the pending builder after a successful attempt.
        if family != nil {
            pendingSelfMember = nil
            pendingOtherMembers = []
        }
    }
    
    // MARK: - Loading
    
    func loadCurrentFamily() async {
        print("[FamilyStore] loadCurrentFamily() called")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            family = try await service.fetchFamily()
            print("[FamilyStore] loadCurrentFamily success: family=\(String(describing: family))")
        } catch {
            // Not being in a family is a valid state; treat errors as UI feedback only.
            errorMessage = (error as NSError).localizedDescription
            print("[FamilyStore] loadCurrentFamily error: \(error)")
        }
    }
    
    // MARK: - Create / Update
    
    func createOrUpdateFamily(
        name: String,
        selfMember: FamilyMember,
        otherMembers: [FamilyMember]
    ) async {
        print("[FamilyStore] createOrUpdateFamily called with name=\(name), self=\(selfMember.name), others=\(otherMembers.map { $0.name })")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            family = try await service.createFamily(
                name: name,
                selfMember: selfMember,
                otherMembers: otherMembers.isEmpty ? nil : otherMembers
            )
            print("[FamilyStore] createOrUpdateFamily success, family name=\(family?.name ?? "nil")")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            print("[FamilyStore] createOrUpdateFamily error: \(error)")
        }
    }
    
    // MARK: - Members
    
    func addMember(_ member: FamilyMember) async {
        print("[FamilyStore] addMember called for \(member.name)")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            family = try await service.addMember(member)
            print("[FamilyStore] addMember success, family name=\(family?.name ?? "nil")")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            print("[FamilyStore] addMember error: \(error)")
        }
    }
    
    func editMember(_ member: FamilyMember) async {
        print("[FamilyStore] editMember called for \(member.id)")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            family = try await service.editMember(member)
            print("[FamilyStore] editMember success for \(member.id)")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            print("[FamilyStore] editMember error: \(error)")
        }
    }
    
    func deleteMember(id: UUID) async {
        print("[FamilyStore] deleteMember called for id=\(id)")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            family = try await service.deleteMember(id: id)
            print("[FamilyStore] deleteMember success, family name=\(family?.name ?? "nil")")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            print("[FamilyStore] deleteMember error: \(error)")
        }
    }
    
    // MARK: - Invites
    
    func invite(memberId: UUID) async -> String? {
        print("[FamilyStore] invite called for memberId=\(memberId)")
        isInviting = true
        errorMessage = nil
        defer { isInviting = false }
        
        do {
            let code = try await service.createInvite(for: memberId)
            print("[FamilyStore] invite success, code=\(code)")
            return code
        } catch {
            errorMessage = (error as NSError).localizedDescription
            print("[FamilyStore] invite error: \(error)")
            return nil
        }
    }
    
    func join(inviteCode: String) async {
        print("[FamilyStore] join called with code=\(inviteCode)")
        isJoining = true
        errorMessage = nil
        defer { isJoining = false }
        
        do {
            family = try await service.joinFamily(inviteCode: inviteCode)
            print("[FamilyStore] join success, family name=\(family?.name ?? "nil")")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            print("[FamilyStore] join error: \(error)")
        }
    }
    
    func leave() async {
        print("[FamilyStore] leave called")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await service.leaveFamily()
            family = nil
            print("[FamilyStore] leave success, family cleared")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            print("[FamilyStore] leave error: \(error)")
        }
    }
}


