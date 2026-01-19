import Foundation
import Observation
import UIKit
import os

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
    
    /// Tracks the number of pending avatar uploads
    private(set) var pendingUploadCount: Int = 0

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
            Log.debug("FamilyStore", "Ignoring empty self member name")
            return
        }
        let color = randomColor()
        Log.debug("FamilyStore", "Setting pending self member name: \(trimmed), color: \(color)")
        
        pendingSelfMember = FamilyMember(
            id: UUID(),
            name: trimmed,
            color: color,
            joined: true,
            imageFileHash: nil
        )
    }
    
    /// Set the pending self member from an existing FamilyMember (used when creating family from Settings)
    func setPendingSelfMemberFromExisting(_ member: FamilyMember) {
        Log.debug("FamilyStore", "Setting pending self member from existing: \(member.name)")
        pendingSelfMember = member
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

    /// Set the avatar for the pending self member using a memoji storage path
    /// from the `memoji-images` bucket, without re-uploading the PNG. Also
    /// updates the member color to match the memoji background if provided.
    func setPendingSelfMemberAvatarFromMemoji(storagePath: String, backgroundColorHex: String? = nil) async {
        guard !storagePath.isEmpty else {
            Log.debug("FamilyStore", "setPendingSelfMemberAvatarFromMemoji: Empty storagePath, skipping")
            return
        }
        guard var member = pendingSelfMember else {
            Log.debug("FamilyStore", "setPendingSelfMemberAvatarFromMemoji: No pending self member, skipping")
            return
        }

        member.imageFileHash = storagePath

        if let bgHex = backgroundColorHex, !bgHex.isEmpty {
            let normalizedColor = bgHex.hasPrefix("#") ? bgHex : "#\(bgHex)"
            member.color = normalizedColor
        }

        pendingSelfMember = member
        Log.debug("FamilyStore", "setPendingSelfMemberAvatarFromMemoji: ✅ Assigned memoji path=\(storagePath) to pending self member \(member.name)")
    }
    
    /// Upload and set the avatar image for the pending self member immediately.
    /// This uploads the image to Supabase and sets the imageFileHash to the uploaded hash.
    /// The image is uploaded as a transparent PNG; background color is stored separately in member.color.
    /// - Parameters:
    ///   - image: The image to upload (transparent PNG)
    ///   - webService: WebService instance for uploading
    ///   - backgroundColorHex: Optional background color hex. If provided, updates member.color
    func setPendingSelfMemberAvatar(image: UIImage, webService: WebService, backgroundColorHex: String? = nil) async {
        // CRITICAL: Capture member data immediately to prevent accessing deallocated objects
        guard var member = pendingSelfMember else {
            Log.debug("FamilyStore", "setPendingSelfMemberAvatar: No pending self member, skipping upload")
            return
        }
        
        // Capture member properties immediately
        let memberName = member.name
        
        // CRITICAL: UIImage.size access must be on main thread - wrap in MainActor.run
        Log.debug("FamilyStore", "setPendingSelfMemberAvatar: Before image.size access - Thread.isMainThread=\(Thread.isMainThread)")
        let isValid = await MainActor.run {
            let isMainThread = Thread.isMainThread
            Log.debug("FamilyStore", "setPendingSelfMemberAvatar: Inside MainActor.run - Thread.isMainThread=\(isMainThread)")
            let width = image.size.width
            let height = image.size.height
            Log.debug("FamilyStore", "setPendingSelfMemberAvatar: image.size accessed - width=\(width), height=\(height)")
            return width > 0 && height > 0 && width.isFinite && height.isFinite
        }
        Log.debug("FamilyStore", "setPendingSelfMemberAvatar: After MainActor.run - Thread.isMainThread=\(Thread.isMainThread), isValid=\(isValid)")
        guard isValid else {
            Log.debug("FamilyStore", "setPendingSelfMemberAvatar: Image is invalid, skipping upload")
            return
        }
        
        pendingUploadCount += 1
        defer { pendingUploadCount = max(0, pendingUploadCount - 1) }
        
        do {
            Log.debug("FamilyStore", "setPendingSelfMemberAvatar: Uploading avatar image for \(memberName)")
            // Upload transparent PNG image directly (no compositing needed)
            let imageFileHash = try await webService.uploadImage(image: image)
            Log.debug("FamilyStore", "setPendingSelfMemberAvatar: ✅ Uploaded avatar, imageFileHash=\(imageFileHash)")
            member.imageFileHash = imageFileHash
            
            // Update member color if provided
            if let bgHex = backgroundColorHex, !bgHex.isEmpty {
                let normalizedColor = bgHex.hasPrefix("#") ? bgHex : "#\(bgHex)"
                member.color = normalizedColor
            }
            
            pendingSelfMember = member
        } catch {
            Log.error("FamilyStore", "setPendingSelfMemberAvatar: ❌ Failed to upload avatar: \(error.localizedDescription)")
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
            Log.debug("FamilyStore", "Ignoring empty other member name")
            return
        }
        let color = randomColor()
        Log.debug("FamilyStore", "Adding pending other member: \(trimmed), color: \(color)")
        
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

    /// Set the avatar for the last pending other member using a memoji storage path
    /// from the `memoji-images` bucket, without re-uploading the PNG. Also updates
    /// the member color to match the memoji background if provided.
    func setAvatarForLastPendingOtherMemberFromMemoji(storagePath: String, backgroundColorHex: String? = nil) async {
        guard !pendingOtherMembers.isEmpty else {
            Log.debug("FamilyStore", "setAvatarForLastPendingOtherMemberFromMemoji: No pending other members, skipping")
            return
        }
        guard !storagePath.isEmpty else {
            Log.debug("FamilyStore", "setAvatarForLastPendingOtherMemberFromMemoji: Empty storagePath, skipping")
            return
        }

        var last = pendingOtherMembers.removeLast()
        last.imageFileHash = storagePath

        if let bgHex = backgroundColorHex, !bgHex.isEmpty {
            let normalizedColor = bgHex.hasPrefix("#") ? bgHex : "#\(bgHex)"
            last.color = normalizedColor
        }

        pendingOtherMembers.append(last)
        Log.debug("FamilyStore", "setAvatarForLastPendingOtherMemberFromMemoji: ✅ Assigned memoji path=\(storagePath) to pending other member \(last.name)")
    }
    
    /// Upload and set the avatar image for the last pending other member immediately.
    /// This uploads the image to Supabase and sets the imageFileHash to the uploaded hash.
    /// The image is uploaded as a transparent PNG; background color is stored separately in member.color.
    /// - Parameters:
    ///   - image: The image to upload (transparent PNG)
    ///   - webService: WebService instance for uploading
    ///   - backgroundColorHex: Optional background color hex. If provided, updates member.color
    func setAvatarForLastPendingOtherMember(image: UIImage, webService: WebService, backgroundColorHex: String? = nil) async {
        guard !pendingOtherMembers.isEmpty else {
            Log.debug("FamilyStore", "setAvatarForLastPendingOtherMember: No pending other members, skipping upload")
            return
        }
        
        var last = pendingOtherMembers.removeLast()
        
        // CRITICAL: UIImage.size access must be on main thread - wrap in MainActor.run
        Log.debug("FamilyStore", "setAvatarForLastPendingOtherMember: Before image.size access - Thread.isMainThread=\(Thread.isMainThread)")
        let isValid = await MainActor.run {
            let isMainThread = Thread.isMainThread
            Log.debug("FamilyStore", "setAvatarForLastPendingOtherMember: Inside MainActor.run - Thread.isMainThread=\(isMainThread)")
            let width = image.size.width
            let height = image.size.height
            Log.debug("FamilyStore", "setAvatarForLastPendingOtherMember: image.size accessed - width=\(width), height=\(height)")
            return width > 0 && height > 0 && width.isFinite && height.isFinite
        }
        Log.debug("FamilyStore", "setAvatarForLastPendingOtherMember: After MainActor.run - Thread.isMainThread=\(Thread.isMainThread), isValid=\(isValid)")
        guard isValid else {
            Log.debug("FamilyStore", "setAvatarForLastPendingOtherMember: Image is invalid, skipping upload")
            pendingOtherMembers.append(last)
            return
        }
        
        pendingUploadCount += 1
        defer { pendingUploadCount = max(0, pendingUploadCount - 1) }
        
        do {
            Log.debug("FamilyStore", "setAvatarForLastPendingOtherMember: Uploading avatar image for \(last.name)")
            // Upload transparent PNG image directly (no compositing needed)
            let imageFileHash = try await webService.uploadImage(image: image)
            Log.debug("FamilyStore", "setAvatarForLastPendingOtherMember: ✅ Uploaded avatar, imageFileHash=\(imageFileHash)")
            last.imageFileHash = imageFileHash
            
            // Update member color if provided
            if let bgHex = backgroundColorHex, !bgHex.isEmpty {
                let normalizedColor = bgHex.hasPrefix("#") ? bgHex : "#\(bgHex)"
                last.color = normalizedColor
            }
            
            pendingOtherMembers.append(last)
        } catch {
            Log.error("FamilyStore", "setAvatarForLastPendingOtherMember: ❌ Failed to upload avatar: \(error.localizedDescription)")
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

    /// Set the avatar for a specific pending other member using a memoji storage
    /// path from the `memoji-images` bucket, without re-uploading the PNG. Also
    /// updates the member color to match the memoji background if provided.
    func setAvatarForPendingOtherMemberFromMemoji(id: UUID, storagePath: String, backgroundColorHex: String? = nil) async {
        guard !storagePath.isEmpty else {
            Log.debug("FamilyStore", "setAvatarForPendingOtherMemberFromMemoji: Empty storagePath, skipping")
            return
        }

        guard let idx = pendingOtherMembers.firstIndex(where: { $0.id == id }) else {
            Log.debug("FamilyStore", "setAvatarForPendingOtherMemberFromMemoji: Member not found for id=\(id), skipping")
            return
        }

        pendingOtherMembers[idx].imageFileHash = storagePath

        if let bgHex = backgroundColorHex, !bgHex.isEmpty {
            let normalizedColor = bgHex.hasPrefix("#") ? bgHex : "#\(bgHex)"
            pendingOtherMembers[idx].color = normalizedColor
        }

        Log.debug("FamilyStore", "setAvatarForPendingOtherMemberFromMemoji: ✅ Assigned memoji path=\(storagePath) to pending member \(pendingOtherMembers[idx].name)")
    }
    
    /// Upload and set the avatar image for a specific pending other member immediately.
    /// This uploads the image to Supabase and sets the imageFileHash to the uploaded hash.
    /// The image is uploaded as a transparent PNG; background color is stored separately in member.color.
    /// - Parameters:
    ///   - id: Member ID
    ///   - image: The image to upload (transparent PNG)
    ///   - webService: WebService instance for uploading
    ///   - backgroundColorHex: Optional background color hex. If provided, updates member.color
    func setAvatarForPendingOtherMember(id: UUID, image: UIImage, webService: WebService, backgroundColorHex: String? = nil) async {
        // CRITICAL: Capture member data immediately to prevent accessing deallocated objects
        guard let idx = pendingOtherMembers.firstIndex(where: { $0.id == id }) else {
            Log.debug("FamilyStore", "setAvatarForPendingOtherMember: Member not found for id=\(id), skipping upload")
            return
        }
        
        // Capture member properties immediately
        let memberName = pendingOtherMembers[idx].name
        
        // CRITICAL: UIImage.size access must be on main thread - wrap in MainActor.run
        Log.debug("FamilyStore", "setAvatarForPendingOtherMember: Before image.size access - Thread.isMainThread=\(Thread.isMainThread)")
        let isValid = await MainActor.run {
            let isMainThread = Thread.isMainThread
            Log.debug("FamilyStore", "setAvatarForPendingOtherMember: Inside MainActor.run - Thread.isMainThread=\(isMainThread)")
            let width = image.size.width
            let height = image.size.height
            Log.debug("FamilyStore", "setAvatarForPendingOtherMember: image.size accessed - width=\(width), height=\(height)")
            return width > 0 && height > 0 && width.isFinite && height.isFinite
        }
        Log.debug("FamilyStore", "setAvatarForPendingOtherMember: After MainActor.run - Thread.isMainThread=\(Thread.isMainThread), isValid=\(isValid)")
        guard isValid else {
            Log.debug("FamilyStore", "setAvatarForPendingOtherMember: Image is invalid, skipping upload")
            return
        }
        
        pendingUploadCount += 1
        defer { pendingUploadCount = max(0, pendingUploadCount - 1) }
        
        do {
            Log.debug("FamilyStore", "setAvatarForPendingOtherMember: Uploading avatar image for \(memberName)")
            // Upload transparent PNG image directly (no compositing needed)
            let imageFileHash = try await webService.uploadImage(image: image)
            Log.debug("FamilyStore", "setAvatarForPendingOtherMember: ✅ Uploaded avatar, imageFileHash=\(imageFileHash)")
            pendingOtherMembers[idx].imageFileHash = imageFileHash
            
            // Update member color if provided
            if let bgHex = backgroundColorHex, !bgHex.isEmpty {
                let normalizedColor = bgHex.hasPrefix("#") ? bgHex : "#\(bgHex)"
                pendingOtherMembers[idx].color = normalizedColor
            }
        } catch {
            Log.error("FamilyStore", "setAvatarForPendingOtherMember: ❌ Failed to upload avatar: \(error.localizedDescription)")
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
            Log.debug("FamilyStore", "createFamilyFromPendingIfNeeded: no pending self member, skipping")
            return
        }
        
        let others = pendingOtherMembers
        let familyName = "\(selfMember.name)'s Family"
        Log.debug("FamilyStore", "Creating family from pending. name=\(familyName), self=\(selfMember.name), others=\(others.map { $0.name })")
        
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
    
    /// Adds pending other members to the existing family (used when creating family from Settings)
    func addPendingMembersToExistingFamily() async {
        guard family != nil else {
            Log.debug("FamilyStore", "addPendingMembersToExistingFamily: no existing family, falling back to createFamilyFromPendingIfNeeded")
            await createFamilyFromPendingIfNeeded()
            return
        }
        
        let others = pendingOtherMembers
        Log.debug("FamilyStore", "Adding pending members to existing family: \(others.map { $0.name })")
        
        // Add each pending member individually
        for member in others {
            await addMember(member)
        }
        
        // Clear the pending builder after successful addition
        if family != nil {
            pendingSelfMember = nil
            pendingOtherMembers = []
        }
    }
    
    /// Waits for all pending avatar uploads to complete before allowing navigation.
    /// This prevents users from navigating away while uploads are in progress.
    func waitForPendingUploads() async {
        while pendingUploadCount > 0 {
            // Poll every 100ms to check if uploads are complete
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        Log.debug("FamilyStore", "waitForPendingUploads: All uploads completed")
    }
    
    // MARK: - Loading
    
    func loadCurrentFamily() async {
        Log.debug("FamilyStore", "loadCurrentFamily() called")
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
                Log.debug("FamilyStore", "loadCurrentFamily: Auto-selected self member for single-member family")
            }
            
            Log.debug("FamilyStore", "loadCurrentFamily success: family=\(String(describing: family))")
        } catch {
            // Not being in a family is a valid state; treat errors as UI feedback only.
            errorMessage = (error as NSError).localizedDescription
            Log.error("FamilyStore", "loadCurrentFamily error: \(error)")
        }
    }
    
    // MARK: - Create / Update
    
    func createOrUpdateFamily(
        name: String,
        selfMember: FamilyMember,
        otherMembers: [FamilyMember]
    ) async {
        Log.debug("FamilyStore", "🔵 createOrUpdateFamily called")
        Log.debug("FamilyStore", "📝 Parameters - name: \(name), self: \(selfMember.name) (id: \(selfMember.id)), others: \(otherMembers.map { $0.name })")
        isLoading = true
        errorMessage = nil
        defer { 
            isLoading = false
            Log.debug("FamilyStore", "✅ createOrUpdateFamily completed - isLoading: false")
        }
        
        do {
            Log.debug("FamilyStore", "⏳ Calling service.createFamily...")
            family = try await service.createFamily(
                name: name,
                selfMember: selfMember,
                otherMembers: otherMembers.isEmpty ? nil : otherMembers
            )
            
            // Sync pending invite status after update
            syncPendingInviteStatus()
            
            Log.debug("FamilyStore", "✅ createOrUpdateFamily success - family name: \(family?.name ?? "nil")")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            Log.error("FamilyStore", "❌ createOrUpdateFamily error: \(error)")
            Log.error("FamilyStore", "❌ Error message: \(errorMessage ?? "nil")")
            if let networkError = error as? NetworkError {
                Log.error("FamilyStore", "❌ NetworkError details: \(networkError)")
            } else if let urlError = error as? URLError {
                Log.error("FamilyStore", "❌ URLError code: \(urlError.code.rawValue), description: \(urlError.localizedDescription)")
            }
        }
    }
    
    /// Updates an existing family's name and members
    func updateFamily(
        name: String,
        selfMember: FamilyMember,
        otherMembers: [FamilyMember]
    ) async {
        Log.debug("FamilyStore", "🔵 updateFamily called")
        Log.debug("FamilyStore", "📝 Parameters - name: \(name), self: \(selfMember.name) (id: \(selfMember.id)), others: \(otherMembers.map { $0.name })")
        isLoading = true
        errorMessage = nil
        defer { 
            isLoading = false
            Log.debug("FamilyStore", "✅ updateFamily completed - isLoading: false")
        }
        
        do {
            Log.debug("FamilyStore", "⏳ Calling service.updateFamily...")
            family = try await service.updateFamily(
                name: name,
                selfMember: selfMember,
                otherMembers: otherMembers.isEmpty ? nil : otherMembers
            )
            
            // Sync pending invite status after update
            syncPendingInviteStatus()
            
            Log.debug("FamilyStore", "✅ updateFamily success - family name: \(family?.name ?? "nil")")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            Log.error("FamilyStore", "❌ updateFamily error: \(error)")
            Log.error("FamilyStore", "❌ Error message: \(errorMessage ?? "nil")")
            if let networkError = error as? NetworkError {
                Log.error("FamilyStore", "❌ NetworkError details: \(networkError)")
            } else if let urlError = error as? URLError {
                Log.error("FamilyStore", "❌ URLError code: \(urlError.code.rawValue), description: \(urlError.localizedDescription)")
            }
        }
    }
    
    // MARK: - Members
    
    func addMember(_ member: FamilyMember) async {
        Log.debug("FamilyStore", "addMember called for \(member.name)")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            family = try await service.addMember(member)
            syncPendingInviteStatus()
            Log.debug("FamilyStore", "addMember success, family name=\(family?.name ?? "nil")")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            Log.error("FamilyStore", "addMember error: \(error)")
        }
    }
    
    func editMember(_ member: FamilyMember) async {
        Log.debug("FamilyStore", "editMember called for \(member.id)")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let updatedFamily = try await service.editMember(member)
            family = updatedFamily
            Log.debug("FamilyStore", "editMember success for \(member.id)")
            if let updatedMember = ([updatedFamily.selfMember] + updatedFamily.otherMembers).first(where: { $0.id == member.id }) {
                Log.debug("FamilyStore", "editMember updated member \(updatedMember.name) has imageFileHash=\(updatedMember.imageFileHash ?? "nil")")
            }
        } catch {
            errorMessage = (error as NSError).localizedDescription
            Log.error("FamilyStore", "editMember error: \(error)")
        }
    }
    
    func deleteMember(id: UUID) async {
        Log.debug("FamilyStore", "deleteMember called for id=\(id)")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            family = try await service.deleteMember(id: id)
            Log.debug("FamilyStore", "deleteMember success, family name=\(family?.name ?? "nil")")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            Log.error("FamilyStore", "deleteMember error: \(error)")
        }
    }
    
    // MARK: - Invites
    
    func invite(memberId: UUID) async -> String? {
        Log.debug("FamilyStore", "invite called for memberId=\(memberId)")
        isInviting = true
        errorMessage = nil
        defer { isInviting = false }
        
        do {
            let code = try await service.createInvite(for: memberId)
            Log.debug("FamilyStore", "invite success, code=\(code)")
            setInvitePendingForPendingOtherMember(id: memberId, pending: true)
            return code
        } catch {
            errorMessage = (error as NSError).localizedDescription
            Log.error("FamilyStore", "invite error: \(error)")
            return nil
        }
    }
    
    func join(inviteCode: String) async {
        Log.debug("FamilyStore", "join called with code=\(inviteCode)")
        isJoining = true
        errorMessage = nil
        defer { isJoining = false }
        
        do {
            family = try await service.joinFamily(inviteCode: inviteCode)
            Log.debug("FamilyStore", "join success, family name=\(family?.name ?? "nil")")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            Log.error("FamilyStore", "join error: \(error)")
        }
    }
    
    func leave() async {
        Log.debug("FamilyStore", "leave called")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await service.leaveFamily()
            family = nil
            Log.debug("FamilyStore", "leave success, family cleared")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            Log.error("FamilyStore", "leave error: \(error)")
        }
    }

    /// Creates a default family named "Bite Buddy" for the "Just Me" flow using the standard family endpoint.
    func createBiteBuddyFamily() async {
        Log.debug("FamilyStore", "createBiteBuddyFamily called")
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
            Log.debug("FamilyStore", "createBiteBuddyFamily success, family name=\(family?.name ?? "nil"), selectedMemberId=\(selectedMemberId?.uuidString ?? "nil")")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            Log.error("FamilyStore", "createBiteBuddyFamily error: \(error)")
        }
    }
    
    // MARK: - Immediate Actions (Throwing)
    
    /// Creates a family immediately with the given self name.
    /// Throws error for UI handling (Toast/Navigation blocking).
    func createFamilyImmediate(selfName: String) async throws {
        Log.debug("FamilyStore", "🔵 createFamilyImmediate called")
        Log.debug("FamilyStore", "📝 Parameter - selfName: \(selfName)")
        isLoading = true
        errorMessage = nil
        defer { 
            isLoading = false
            Log.debug("FamilyStore", "✅ createFamilyImmediate completed - isLoading: false")
        }
        
        let trimmed = selfName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Log.error("FamilyStore", "❌ Validation failed - name is empty after trimming")
            throw NSError(domain: "FamilyStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Name cannot be empty"])
        }
        
        Log.debug("FamilyStore", "✅ Name validation passed - trimmed name: \(trimmed)")
        
        // Check if we have a pending self member logic we should respect?
        // Or just create fresh? The flow "WhatsYourName" usually sets pending self member.
        // We will respect pending color/avatar if available, otherwise new.
        
        let selfMember: FamilyMember
        if let pending = pendingSelfMember {
            Log.debug("FamilyStore", "📋 Using pending self member - id: \(pending.id), color: \(pending.color), hasImage: \(pending.imageFileHash != nil)")
            selfMember = FamilyMember(
                id: pending.id,
                name: trimmed,
                color: pending.color,
                joined: true,
                imageFileHash: pending.imageFileHash
            )
        } else {
            let newColor = randomColor()
            Log.debug("FamilyStore", "🆕 Creating new self member - id: \(UUID()), color: \(newColor)")
            selfMember = FamilyMember(
                id: UUID(),
                name: trimmed,
                color: newColor,
                joined: true,
                imageFileHash: nil
            )
        }
        
        let familyName = "\(trimmed)'s Family"
        Log.debug("FamilyStore", "📝 Family name: \(familyName)")
        
        do {
            Log.debug("FamilyStore", "⏳ Calling service.createFamily...")
            family = try await service.createFamily(
                name: familyName,
                selfMember: selfMember,
                otherMembers: nil
            )
            
            if let family = family {
                Log.debug("FamilyStore", "✅ Family created successfully - name: \(family.name)")
                selectedMemberId = family.selfMember.id
                Log.debug("FamilyStore", "✅ Selected member ID set to: \(selectedMemberId?.uuidString)")
                // Clear pending self member as it is now persisted
                pendingSelfMember = nil
                Log.debug("FamilyStore", "✅ Cleared pending self member")
            } else {
                Log.debug("FamilyStore", "⚠️ Family is nil after creation")
            }
        } catch {
            Log.error("FamilyStore", "❌ createFamilyImmediate failed with error: \(error)")
            if let networkError = error as? NetworkError {
                Log.error("FamilyStore", "❌ NetworkError details: \(networkError)")
            } else if let urlError = error as? URLError {
                Log.error("FamilyStore", "❌ URLError code: \(urlError.code.rawValue), description: \(urlError.localizedDescription)")
            }
            throw error
        }
    }
    
    /// Adds a member immediately with the given name and optional avatar.
    /// Uploads image if provided.
    /// Throws error for UI handling.
    /// Returns the added member.
    @discardableResult
    func addMemberImmediate(
        name: String,
        image: UIImage? = nil,
        storagePath: String? = nil,
        color: String? = nil,
        webService: WebService
    ) async throws -> FamilyMember {
        Log.debug("FamilyStore", "addMemberImmediate called with name=\(name)")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "FamilyStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Name cannot be empty"])
        }
        
        var avatarHash: String? = storagePath
        
        if let image = image {
            pendingUploadCount += 1
             // Using task priority to ensure upload logic runs
            do {
                Log.debug("FamilyStore", "addMemberImmediate: Uploading avatar image for \(trimmed)")
                let hash = try await webService.uploadImage(image: image)
                Log.debug("FamilyStore", "addMemberImmediate: ✅ Uploaded avatar hash=\(hash)")
                avatarHash = hash
                pendingUploadCount = max(0, pendingUploadCount - 1)
            } catch {
                pendingUploadCount = max(0, pendingUploadCount - 1)
                Log.error("FamilyStore", "addMemberImmediate: ❌ Failed to upload avatar: \(error.localizedDescription)")
                // Fail soft: Proceed without avatar if upload fails, instead of blocking member creation
                avatarHash = nil
            }
        }
        
        // Use provided color or generate random
        let memberColor = color ?? randomColor()
        
        let member = FamilyMember(
            id: UUID(),
            name: trimmed,
            color: memberColor,
            joined: false, // Other members are not joined by default (requires invite)
            imageFileHash: avatarHash
        )
        
        family = try await service.addMember(member)
        
        // Update pending invite status
        syncPendingInviteStatus()
        
        if let found = family?.otherMembers.first(where: { $0.id == member.id }) {
            return found
        }
        return member
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


