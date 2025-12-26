import Foundation
import Observation
import UIKit

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
    
    private let pendingInviteIdsKey = "ingredicheck_pending_invite_ids"
    private var pendingInviteIds: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: pendingInviteIdsKey) ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: pendingInviteIdsKey)
        }
    }
    
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
    
    /// Set or update the avatar image for the pending self member.
    /// This method accepts an asset name string (for backward compatibility).
    /// For immediate upload, use setPendingSelfMemberAvatar(image:webService:) instead.
    func setPendingSelfMemberAvatar(imageName: String?) {
        guard let imageName else { return }
        guard var member = pendingSelfMember else { return }
        member.imageFileHash = imageName
        pendingSelfMember = member
    }
    
    /// Upload and set the avatar image for the pending self member immediately.
    /// This uploads the image to Supabase and sets the imageFileHash to the uploaded hash.
    /// The image is composited with the background color before uploading.
    /// - Parameters:
    ///   - image: The image to upload
    ///   - webService: WebService instance for uploading
    ///   - backgroundColorHex: Optional background color hex. If nil, uses member.color
    func setPendingSelfMemberAvatar(image: UIImage, webService: WebService, backgroundColorHex: String? = nil) async {
        // CRITICAL: Capture member data immediately to prevent accessing deallocated objects
        guard var member = pendingSelfMember else {
            print("[FamilyStore] setPendingSelfMemberAvatar: No pending self member, skipping upload")
            return
        }
        
        // Capture member properties immediately
        let memberName = member.name
        let memberColor = member.color
        let bgColor = backgroundColorHex ?? memberColor
        
        // Validate image is still valid before processing
        guard image.cgImage != nil,
              image.size.width > 0 && image.size.height > 0,
              image.size.width.isFinite && image.size.height.isFinite else {
            print("[FamilyStore] setPendingSelfMemberAvatar: Image is invalid, skipping upload")
            return
        }
        
        do {
            print("[FamilyStore] setPendingSelfMemberAvatar: Uploading avatar image for \(memberName)")
            // Composite image with background color before uploading
            // The image passed here should already be a deep copy from handleAssignAvatar
            let compositedImage = image.compositedWithBackground(backgroundColorHex: bgColor) ?? image
            let imageFileHash = try await webService.uploadImage(image: compositedImage)
            print("[FamilyStore] setPendingSelfMemberAvatar: ✅ Uploaded avatar, imageFileHash=\(imageFileHash)")
            member.imageFileHash = imageFileHash
            pendingSelfMember = member
        } catch {
            print("[FamilyStore] setPendingSelfMemberAvatar: ❌ Failed to upload avatar: \(error.localizedDescription)")
            // Don't set imageFileHash if upload fails - user can retry later
        }
    }
    
    /// Update the name for the pending self member.
    func updatePendingSelfMemberName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard var member = pendingSelfMember else { return }
        member.name = trimmed
        pendingSelfMember = member
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
    
    /// Set avatar for the last pending other member.
    /// This method accepts an asset name string (for backward compatibility).
    /// For immediate upload, use setAvatarForLastPendingOtherMember(image:webService:) instead.
    func setAvatarForLastPendingOtherMember(imageName: String?) {
        guard let imageName else { return }
        guard !pendingOtherMembers.isEmpty else { return }
        var last = pendingOtherMembers.removeLast()
        last.imageFileHash = imageName
        pendingOtherMembers.append(last)
    }
    
    /// Upload and set the avatar image for the last pending other member immediately.
    /// This uploads the image to Supabase and sets the imageFileHash to the uploaded hash.
    /// The image is composited with the background color before uploading.
    /// - Parameters:
    ///   - image: The image to upload
    ///   - webService: WebService instance for uploading
    ///   - backgroundColorHex: Optional background color hex. If nil, uses member.color
    func setAvatarForLastPendingOtherMember(image: UIImage, webService: WebService, backgroundColorHex: String? = nil) async {
        guard !pendingOtherMembers.isEmpty else {
            print("[FamilyStore] setAvatarForLastPendingOtherMember: No pending other members, skipping upload")
            return
        }
        
        var last = pendingOtherMembers.removeLast()
        
        do {
            print("[FamilyStore] setAvatarForLastPendingOtherMember: Uploading avatar image for \(last.name)")
            // Use provided background color or fall back to member.color
            let bgColor = backgroundColorHex ?? last.color
            // Composite image with background color before uploading
            let compositedImage = image.compositedWithBackground(backgroundColorHex: bgColor) ?? image
            let imageFileHash = try await webService.uploadImage(image: compositedImage)
            print("[FamilyStore] setAvatarForLastPendingOtherMember: ✅ Uploaded avatar, imageFileHash=\(imageFileHash)")
            last.imageFileHash = imageFileHash
            pendingOtherMembers.append(last)
        } catch {
            print("[FamilyStore] setAvatarForLastPendingOtherMember: ❌ Failed to upload avatar: \(error.localizedDescription)")
            // Restore member without imageFileHash if upload fails
            pendingOtherMembers.append(last)
        }
    }
    
    func updatePendingOtherMemberName(id: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = pendingOtherMembers.firstIndex(where: { $0.id == id }) {
            pendingOtherMembers[idx].name = trimmed
        }
    }
    
    /// Set avatar for a specific pending other member.
    /// This method accepts an asset name string (for backward compatibility).
    /// For immediate upload, use setAvatarForPendingOtherMember(id:image:webService:) instead.
    func setAvatarForPendingOtherMember(id: UUID, imageName: String?) {
        guard let imageName else { return }
        if let idx = pendingOtherMembers.firstIndex(where: { $0.id == id }) {
            pendingOtherMembers[idx].imageFileHash = imageName
        }
    }
    
    /// Upload and set the avatar image for a specific pending other member immediately.
    /// This uploads the image to Supabase and sets the imageFileHash to the uploaded hash.
    /// The image is composited with the background color before uploading.
    /// - Parameters:
    ///   - id: Member ID
    ///   - image: The image to upload
    ///   - webService: WebService instance for uploading
    ///   - backgroundColorHex: Optional background color hex. If nil, uses member.color
    func setAvatarForPendingOtherMember(id: UUID, image: UIImage, webService: WebService, backgroundColorHex: String? = nil) async {
        // CRITICAL: Capture member data immediately to prevent accessing deallocated objects
        guard let idx = pendingOtherMembers.firstIndex(where: { $0.id == id }) else {
            print("[FamilyStore] setAvatarForPendingOtherMember: Member not found for id=\(id), skipping upload")
            return
        }
        
        // Capture member properties immediately
        let memberName = pendingOtherMembers[idx].name
        let memberColor = pendingOtherMembers[idx].color
        let bgColor = backgroundColorHex ?? memberColor
        
        // Validate image is still valid before processing
        guard image.cgImage != nil,
              image.size.width > 0 && image.size.height > 0,
              image.size.width.isFinite && image.size.height.isFinite else {
            print("[FamilyStore] setAvatarForPendingOtherMember: Image is invalid, skipping upload")
            return
        }
        
        do {
            print("[FamilyStore] setAvatarForPendingOtherMember: Uploading avatar image for \(memberName)")
            // Composite image with background color before uploading
            // The image passed here should already be a deep copy from handleAssignAvatar
            let compositedImage = image.compositedWithBackground(backgroundColorHex: bgColor) ?? image
            let imageFileHash = try await webService.uploadImage(image: compositedImage)
            print("[FamilyStore] setAvatarForPendingOtherMember: ✅ Uploaded avatar, imageFileHash=\(imageFileHash)")
            pendingOtherMembers[idx].imageFileHash = imageFileHash
        } catch {
            print("[FamilyStore] setAvatarForPendingOtherMember: ❌ Failed to upload avatar: \(error.localizedDescription)")
            // Don't set imageFileHash if upload fails - user can retry later
        }
    }
    
    func setInvitePendingForPendingOtherMember(id: UUID, pending: Bool = true) {
        if let idx = pendingOtherMembers.firstIndex(where: { $0.id == id }) {
            pendingOtherMembers[idx].invitePending = pending
        }
        
        var ids = pendingInviteIds
        if pending {
            ids.insert(id.uuidString)
        } else {
            ids.remove(id.uuidString)
        }
        pendingInviteIds = ids
        
        if var currentFamily = family {
            if let idx = currentFamily.otherMembers.firstIndex(where: { $0.id == id }) {
                currentFamily.otherMembers[idx].invitePending = pending
                self.family = currentFamily
            }
        }
    }

    func removePendingOtherMember(id: UUID) {
        pendingOtherMembers.removeAll { $0.id == id }
        var ids = pendingInviteIds
        ids.remove(id.uuidString)
        pendingInviteIds = ids
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
            
            // Sync pending invite status from local persistence
            syncPendingInviteStatus()
            
            // If this is a single-member family and no member is selected,
            // auto-select the self member so preferences load correctly.
            if let family = family, family.otherMembers.isEmpty, selectedMemberId == nil {
                selectedMemberId = family.selfMember.id
                print("[FamilyStore] loadCurrentFamily: Auto-selected self member for single-member family")
            }
            
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
            
            // Sync pending invite status after update
            syncPendingInviteStatus()
            
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
            syncPendingInviteStatus()
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
            setInvitePendingForPendingOtherMember(id: memberId, pending: true)
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

    /// Creates a default family named "Bite Buddy" for the "Just Me" flow using the standard family endpoint.
    func createBiteBuddyFamily() async {
        print("[FamilyStore] createBiteBuddyFamily called")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let selfMember = FamilyMember(
                id: UUID(),
                name: "Me",
                color: randomColor(),
                joined: true,
                imageFileHash: nil
            )
            
            family = try await service.createFamily(
                name: "Bite Buddy",
                selfMember: selfMember,
                otherMembers: nil
            )
            if let family = family {
                selectedMemberId = family.selfMember.id
            }
            print("[FamilyStore] createBiteBuddyFamily success, family name=\(family?.name ?? "nil"), selectedMemberId=\(selectedMemberId?.uuidString ?? "nil")")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            print("[FamilyStore] createBiteBuddyFamily error: \(error)")
        }
    }

    func resetLocalState() {
        family = nil
        isLoading = false
        isJoining = false
        isInviting = false
        errorMessage = nil
        pendingSelfMember = nil
        pendingOtherMembers = []
    }

    private func syncPendingInviteStatus() {
        guard var f = family else { return }
        
        var currentPendingIds = pendingInviteIds
        var changed = false
        
        // Check other members
        for i in 0..<f.otherMembers.count {
            let memberId = f.otherMembers[i].id.uuidString
            
            if f.otherMembers[i].joined {
                // If they've joined, they're no longer pending
                if currentPendingIds.contains(memberId) {
                    currentPendingIds.remove(memberId)
                    changed = true
                }
                f.otherMembers[i].invitePending = false
            } else if currentPendingIds.contains(memberId) {
                // If we have them as pending locally, mark them
                f.otherMembers[i].invitePending = true
            }
        }
        
        if changed {
            pendingInviteIds = currentPendingIds
        }
        
        self.family = f
    }
}


