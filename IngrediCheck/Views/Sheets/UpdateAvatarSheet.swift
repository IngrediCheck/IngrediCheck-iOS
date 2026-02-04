//
//  UpdateAvatarSheet.swift
//  IngrediCheck
//
//  Created on 23/01/26.
//

import SwiftUI

struct UpdateAvatarSheet: View {
    let memberId: UUID
    let onBack: () -> Void

    @Environment(FamilyStore.self) private var familyStore
    @Environment(MemojiStore.self) private var memojiStore
    @Environment(WebService.self) private var webService
    @Environment(AppNavigationCoordinator.self) private var coordinator

    // Static memojis (same as AddMoreMembers)
    @State private var familyMembersList: [UserModel] = [
        UserModel(familyMemberName: "Memoji 1", familyMemberImage: "memoji_1", backgroundColor: Color(hex: "FFB3BA")),
        UserModel(familyMemberName: "Memoji 2", familyMemberImage: "memoji_2", backgroundColor: Color(hex: "FFDFBA")),
        UserModel(familyMemberName: "Memoji 3", familyMemberImage: "memoji_3", backgroundColor: Color(hex: "FFFFBA")),
        UserModel(familyMemberName: "Memoji 4", familyMemberImage: "memoji_4", backgroundColor: Color(hex: "BAFFC9")),
        UserModel(familyMemberName: "Memoji 5", familyMemberImage: "memoji_5", backgroundColor: Color(hex: "BAE1FF")),
        UserModel(familyMemberName: "Memoji 6", familyMemberImage: "memoji_6", backgroundColor: Color(hex: "E0BBE4")),
        UserModel(familyMemberName: "Memoji 7", familyMemberImage: "memoji_7", backgroundColor: Color(hex: "FFCCCB")),
        UserModel(familyMemberName: "Memoji 8", familyMemberImage: "memoji_8", backgroundColor: Color(hex: "B4E4FF")),
        UserModel(familyMemberName: "Memoji 9", familyMemberImage: "memoji_9", backgroundColor: Color(hex: "C7CEEA")),
        UserModel(familyMemberName: "Memoji 10", familyMemberImage: "memoji_10", backgroundColor: Color(hex: "F0E6FF")),
        UserModel(familyMemberName: "Memoji 11", familyMemberImage: "memoji_11", backgroundColor: Color(hex: "FFE5B4")),
        UserModel(familyMemberName: "Memoji 12", familyMemberImage: "memoji_12", backgroundColor: Color(hex: "E8F5E9")),
        UserModel(familyMemberName: "Memoji 13", familyMemberImage: "memoji_13", backgroundColor: Color(hex: "FFF9C4")),
        UserModel(familyMemberName: "Memoji 14", familyMemberImage: "memoji_14", backgroundColor: Color(hex: "F8BBD0"))
    ]

    @State private var selectedStaticAvatar: UserModel? = nil
    @State private var useCustomAvatar: Bool = false
    @State private var isLoading: Bool = false

    private var currentMember: FamilyMember? {
        guard let family = familyStore.family else {
            // Check pending members
            if let selfMember = familyStore.pendingSelfMember, selfMember.id == memberId {
                return selfMember
            }
            return familyStore.pendingOtherMembers.first(where: { $0.id == memberId })
        }

        if memberId == family.selfMember.id {
            return family.selfMember
        }
        return family.otherMembers.first(where: { $0.id == memberId })
    }

    private var hasSelection: Bool {
        selectedStaticAvatar != nil || useCustomAvatar
    }

    private var previewImage: UIImage? {
        if useCustomAvatar, let customImage = memojiStore.image {
            return customImage
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            headerView
                .padding(.top, 24)

            // Large avatar preview
            avatarPreview
                .padding(.top, 16)
                .padding(.bottom, 20)

            // Title & subtitle
            Microcopy.text(Microcopy.Key.Avatar.Update.title)
                .font(NunitoFont.bold.size(20))
                .foregroundStyle(Color(hex: "#303030"))
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Microcopy.text(Microcopy.Key.Avatar.Update.subtitle)
                .font(ManropeFont.medium.size(14))
                .foregroundStyle(Color(hex: "#949494"))
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

            // Choose Avatar section
            VStack(alignment: .leading, spacing: 12) {
                Microcopy.text(Microcopy.Key.Labels.chooseAvatar)
                    .font(ManropeFont.bold.size(14))
                    .foregroundStyle(Color(hex: "#303030"))
                    .padding(.leading, 20)

                avatarSelectionGrid
            }
            .padding(.bottom, 12)

            // Hint text
            HStack(spacing: 6) {
                Text("💡")
                    .font(.system(size: 14))
                Microcopy.text(Microcopy.Key.Avatar.Update.hint)
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(Color(hex: "#949494"))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            // Save button
            Button {
                Task {
                    await saveAvatar()
                }
            } label: {
                    GreenCapsule(title: Microcopy.string(Microcopy.Key.Common.save), isLoading: isLoading, isDisabled: !hasSelection)
                        .frame(width: 159)
            }
            .disabled(!hasSelection || isLoading)
            .padding(.bottom, 32)
        }
        .background(Color.white)
        .onAppear {
            // Check if returning from generateAvatar with a custom image
            if memojiStore.image != nil && memojiStore.previousRouteForGenerateAvatar == .updateAvatar(memberId: memberId) {
                useCustomAvatar = true
                selectedStaticAvatar = nil
            }

            // Set display name for avatar generation
            if let member = currentMember {
                memojiStore.displayName = member.name
                familyStore.avatarTargetMemberId = member.id
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "#303030"))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Avatar Preview

    private var avatarPreview: some View {
        ZStack {
            if useCustomAvatar, let customImage = memojiStore.image {
                // Show custom generated avatar
                Circle()
                    .fill(Color(hex: memojiStore.backgroundColorHex ?? "#E0BBE4"))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(uiImage: customImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110, height: 110)
                            .clipShape(Circle())
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
            } else if let selected = selectedStaticAvatar {
                // Show selected static avatar
                Circle()
                    .fill(selected.backgroundColor ?? .clear)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(selected.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110, height: 110)
                            .clipShape(Circle())
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
            } else if let member = currentMember {
                // Show current member avatar
                MemberAvatar.large(member: member)
            } else {
                // Fallback placeholder
                Circle()
                    .fill(Color(hex: "#D9D9D9"))
                    .frame(width: 120, height: 120)
            }
        }
    }

    // MARK: - Avatar Selection Grid

    private var avatarSelectionGrid: some View {
        HStack(spacing: 16) {
            // Plus button for custom avatar generation
            Button {
                memojiStore.previousRouteForGenerateAvatar = .updateAvatar(memberId: memberId)
                coordinator.navigateInBottomSheet(.generateAvatar)
            } label: {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 2)
                        .foregroundStyle(Color(hex: "#E0E0E0"))
                        .frame(width: 50, height: 50)

                    Image(systemName: "plus")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(Color(hex: "#E0E0E0"))
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 20)

            // Vertical divider
            Rectangle()
                .fill(Color(hex: "#E0E0E0"))
                .frame(width: 1, height: 50)

            // Scrollable static avatars
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(familyMembersList, id: \.id) { avatar in
                        ZStack(alignment: .topTrailing) {
                            Image(avatar.image)
                                .resizable()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            selectedStaticAvatar?.id == avatar.id ? Color(hex: "#91B640") : Color.clear,
                                            lineWidth: 2
                                        )
                                )

                            // Green checkmark when selected
                            if selectedStaticAvatar?.id == avatar.id {
                                Circle()
                                    .fill(Color(hex: "#2C9C3D"))
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.white)
                                    )
                                    .offset(x: 2, y: -2)
                            }
                        }
                        .onTapGesture {
                            selectedStaticAvatar = avatar
                            useCustomAvatar = false
                        }
                    }
                }
                .padding(.trailing, 20)
            }
        }
    }

    // MARK: - Save Avatar

    @MainActor
    private func saveAvatar() async {
        guard let member = currentMember else { return }

        isLoading = true
        defer { isLoading = false }

        var imageFileHash: String? = nil
        var colorHex: String? = nil

        if useCustomAvatar, let customImage = memojiStore.image {
            // Upload custom avatar
            do {
                let hash = try await webService.uploadImage(image: customImage)
                imageFileHash = hash
                colorHex = memojiStore.backgroundColorHex
            } catch {
                Log.error("UpdateAvatarSheet", "Failed to upload custom avatar: \(error)")
                ToastManager.shared.show(message: Microcopy.string(Microcopy.Key.Errors.Avatar.upload), type: .error)
                return
            }
        } else if let selected = selectedStaticAvatar {
            // Use static memoji path
            imageFileHash = selected.image
            colorHex = selected.backgroundColor?.toHex()
        } else {
            return
        }

        // Update member's avatar
        do {
            try await familyStore.updateMemberAvatar(
                memberId: member.id,
                imageFileHash: imageFileHash,
                color: colorHex
            )

            // Clear memojiStore state
            memojiStore.image = nil
            memojiStore.backgroundColorHex = nil

            // Navigate back
            onBack()
        } catch {
            Log.error("UpdateAvatarSheet", "Failed to update avatar: \(error)")
            ToastManager.shared.show(message: Microcopy.string(Microcopy.Key.Errors.Avatar.save), type: .error)
        }
    }
}

// MARK: - Preview

#Preview("Update Avatar Sheet") {
    UpdateAvatarSheetPreview()
}

private struct UpdateAvatarSheetPreview: View {
    @State private var familyStore = FamilyStore()
    @State private var memojiStore = MemojiStore()
    @State private var webService = WebService()
    @State private var coordinator = AppNavigationCoordinator(initialRoute: .home)
    @State private var memberId: UUID?

    var body: some View {
        Group {
            if let id = memberId {
                UpdateAvatarSheet(memberId: id) {
                    print("Back tapped")
                }
            } else {
                ProgressView()
            }
        }
        .environment(familyStore)
        .environment(memojiStore)
        .environment(webService)
        .environment(coordinator)
        .onAppear {
            // Create a mock member for preview using public method
            familyStore.setPendingSelfMember(name: "John")
            // Get the created member's ID
            memberId = familyStore.pendingSelfMember?.id
        }
    }
}
