//
//  MemberAvatar.swift
//  IngrediCheck
//
//  Centralized avatar component for consistent memoji rendering throughout the app
//

import SwiftUI

/// Centralized avatar view that handles loading, displaying, and updating family member avatars.
/// This component ensures consistent rendering across the app:
/// - Colored circle background
/// - Transparent PNG memoji image on top
/// - Fallback to initial letter if no image
/// - Automatic loading and caching
/// - Handles updates and deletions automatically
struct MemberAvatar: View {
    @Environment(WebService.self) private var webService
    let member: FamilyMember
    let size: CGFloat
    let showBorder: Bool
    let borderWidth: CGFloat
    let imagePadding: CGFloat
    
    @State private var avatarImage: UIImage? = nil
    @State private var loadedHash: String? = nil
    
    /// Initializes a member avatar view
    /// - Parameters:
    ///   - member: The family member to display
    ///   - size: The size of the avatar circle (default: 48)
    ///   - showBorder: Whether to show a white border (default: true)
    ///   - borderWidth: Width of the border (default: 1)
    ///   - imagePadding: Padding between image and circle edge to show background color ring (default: 2)
    init(
        member: FamilyMember,
        size: CGFloat = 48,
        showBorder: Bool = true,
        borderWidth: CGFloat = 1,
        imagePadding: CGFloat = 2
    ) {
        self.member = member
        self.size = size
        self.showBorder = showBorder
        self.borderWidth = borderWidth
        self.imagePadding = imagePadding
    }
    
    var body: some View {
        ZStack {
            // Background circle (behind the image)
            Circle()
                .fill(Color(hex: member.color))
                .frame(width: size, height: size)
            
            // Memoji image on top (transparent PNG should show circle through)
            if let img = avatarImage {
                Image(uiImage: img)
                    .resizable()
                    .renderingMode(.original) // Preserve transparency
                    .scaledToFit() // Preserve aspect ratio
                    .frame(width: size - imagePadding * 2, height: size - imagePadding * 2)
                    .clipShape(Circle())
            } else {
                // Fallback: initial letter
                Text(String(member.name.prefix(1)))
                    .font(NunitoFont.semiBold.size(size * 0.375))
                    .foregroundStyle(.white)
            }
        }
        .overlay(
            Group {
                if showBorder {
                    Circle()
                        .stroke(lineWidth: borderWidth)
                        .foregroundStyle(Color.white)
                }
            }
        )
        .task(id: member.imageFileHash) {
            await loadAvatarIfNeeded()
        }
    }
    
    @MainActor
    private func loadAvatarIfNeeded() async {
        // If there is no hash, clear any cached avatar and fall back to initials.
        guard let hash = member.imageFileHash, !hash.isEmpty else {
            if avatarImage != nil {
                print("[MemberAvatar] imageFileHash cleared for \(member.name), resetting avatarImage")
            }
            avatarImage = nil
            loadedHash = nil
            return
        }

        // If we've already loaded this exact hash, skip re-fetching.
        if loadedHash == hash, let existingImage = avatarImage {
            // Validate image is still valid
            let isValid = await MainActor.run {
                let width = existingImage.size.width
                let height = existingImage.size.height
                return width > 0 && height > 0 && width.isFinite && height.isFinite
            }
            if isValid {
                print("[MemberAvatar] Avatar for \(member.name) already loaded for hash \(hash), skipping reload")
                return
            }
        }
        
        // 1) Try local asset first (for predefined avatars)
        if hash.count < 20 && hash.contains("-") {
            if let local = UIImage(named: hash) {
                let isValid = await MainActor.run {
                    let width = local.size.width
                    let height = local.size.height
                    return width > 0 && height > 0 && width.isFinite && height.isFinite
                }
                if isValid {
                    avatarImage = local
                    loadedHash = hash
                    print("[MemberAvatar] ✅ Loaded local avatar for \(member.name) (hash=\(hash))")
                    return
                }
            }
        }
        
        // 2) Try remote (for memoji images from Supabase)
        print("[MemberAvatar] Loading remote avatar for \(member.name), imageFileHash=\(hash)")
        do {
            let uiImage = try await webService.fetchImage(
                imageLocation: .imageFileHash(hash),
                imageSize: size <= 36 ? .small : (size <= 64 ? .medium : .large)
            )
            
            // Validate loaded image
            let isValid = await MainActor.run {
                let width = uiImage.size.width
                let height = uiImage.size.height
                return width > 0 && height > 0 && width.isFinite && height.isFinite
            }
            
            guard isValid else {
                print("[MemberAvatar] ⚠️ Loaded image has invalid size, skipping")
                avatarImage = nil
                loadedHash = nil
                return
            }
            
            avatarImage = uiImage
            loadedHash = hash
            print("[MemberAvatar] ✅ Loaded remote avatar for \(member.name) (hash=\(hash))")
        } catch {
            print("[MemberAvatar] ❌ Failed to load avatar for \(member.name): \(error.localizedDescription)")
            avatarImage = nil
            loadedHash = nil
        }
    }
}

// MARK: - Convenience Extensions

extension MemberAvatar {
    /// Small avatar (36x36) - typically used in lists and compact views
    static func small(member: FamilyMember) -> some View {
        MemberAvatar(member: member, size: 36, imagePadding: 0)
    }
    
    /// Medium avatar (48x48) - standard size for most views
    static func medium(member: FamilyMember) -> some View {
        MemberAvatar(member: member, size: 48, imagePadding: 2)
    }
    
    /// Large avatar (120x120) - used in profile views and detailed displays
    static func large(member: FamilyMember) -> some View {
        MemberAvatar(member: member, size: 120, borderWidth: 2, imagePadding: 5)
    }
    
    /// Custom size avatar
    static func custom(member: FamilyMember, size: CGFloat, imagePadding: CGFloat = 2) -> some View {
        MemberAvatar(member: member, size: size, imagePadding: imagePadding)
    }
}

#Preview {
    VStack(spacing: 20) {
        MemberAvatar.small(member: FamilyMember(id: UUID(), name: "Alice", color: "#E0BBE4", joined: true, imageFileHash: nil))
        MemberAvatar.medium(member: FamilyMember(id: UUID(), name: "Bob", color: "#BAE1FF", joined: true, imageFileHash: nil))
        MemberAvatar.large(member: FamilyMember(id: UUID(), name: "Charlie", color: "#BAFFC9", joined: true, imageFileHash: nil))
    }
    .padding()
    .environment(WebService())
}

