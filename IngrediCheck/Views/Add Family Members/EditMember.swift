import SwiftUI
import UIKit

struct EditMember: View {
    @Environment(FamilyStore.self) private var familyStore
    @Environment(WebService.self) private var webService
    @Environment(MemojiStore.self) private var memojiStore
    @Environment(AppNavigationCoordinator.self) private var coordinator

    let memberId: UUID
    let isSelf: Bool
    var onSave: () -> Void = { }

    @State private var name: String = ""
    @State private var showError: Bool = false

    @State private var avatarChoices: [UserModel] = [
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
    @State private var selectedAvatar: UserModel? = nil

    var body: some View {
        VStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Update the name & avatar?")
                            .font(NunitoFont.bold.size(22))
                            .foregroundStyle(.grayScale150)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) {
                        Button {
                            // Context-aware back: from Home/Manage Family, dismiss; from onboarding, return to minimal list
                            if case .home = coordinator.currentCanvasRoute {
                                coordinator.navigateInBottomSheet(.homeDefault)
                            } else {
                                coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Update the name and give the avatar a look that truly matches their personality")
                        .font(ManropeFont.medium.size(12))
                        .foregroundStyle(.grayScale120)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Enter Name", text: $name)
                        .padding(16)
                        .background(.grayScale10)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(lineWidth: showError ? 2 : 0.5)
                                .foregroundStyle(showError ? .red : .grayScale60)
                        )
                        .autocorrectionDisabled(true)
                        .onChange(of: name) { _, newValue in
                            if showError && !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                showError = false
                            }
                        }
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Avatar (Optional)")
                        .font(ManropeFont.bold.size(14))
                        .foregroundStyle(.grayScale150)
                        .padding(.leading, 20)

                    HStack(spacing: 16) {
                        // Fixed plus button (does not scroll)
                        Button {
                            // Track that we came from EditMember - need to get the actual route
                            if case .editMember(let memberId, let isSelf) = coordinator.currentBottomSheetRoute {
                                memojiStore.previousRouteForGenerateAvatar = .editMember(memberId: memberId, isSelf: isSelf)
                            } else {
                                // Fallback to addMoreMembersMinimal if we can't determine the route
                                memojiStore.previousRouteForGenerateAvatar = .addMoreMembersMinimal
                            }
                            coordinator.navigateInBottomSheet(.generateAvatar)
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(lineWidth: 2)
                                    .foregroundStyle(.grayScale60)
                                    .frame(width: 48, height: 48)

                                Image(systemName: "plus")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(.grayScale60)
                            }
                        }
                        .buttonStyle(.plain)

                        // Vertical divider
                        Rectangle()
                            .fill(.grayScale60)
                            .frame(width: 1, height: 48)

                        // Scrollable memojis list
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(avatarChoices, id: \.id) { ele in
                                    ZStack(alignment: .topTrailing) {
                                        Image(ele.image)
                                            .resizable()
                                            .frame(width: 50, height: 50)

                                        if selectedAvatar?.id == ele.id {
                                            Circle()
                                                .fill(Color(hex: "2C9C3D"))
                                                .frame(width: 16, height: 16)
                                                .padding(.top, 1)
                                                .overlay(
                                                    Circle()
                                                        .stroke(lineWidth: 1)
                                                        .foregroundStyle(.white)
                                                        .padding(.top, 1)
                                                        .overlay(
                                                            Image("white-rounded-checkmark")
                                                        )
                                                )
                                        }
                                    }
                                    .onTapGesture {
                                        selectedAvatar = ele
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 40)

            Button {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    showError = true
                } else {
                    handleSave(trimmed: trimmed)
                }
            } label: {
                GreenCapsule(title: "Save")
                    .frame(width: 180)
            }
            .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dismissKeyboardOnTap()
        .background(Color.pageBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
        .onAppear {
            // Seed initial values from store
            if isSelf {
                if let me = familyStore.pendingSelfMember {
                    name = me.name
                    if let imageName = me.imageFileHash {
                        selectedAvatar = UserModel(familyMemberName: me.name, familyMemberImage: imageName)
                    }
                }
            } else {
                if let member = familyStore.pendingOtherMembers.first(where: { $0.id == memberId }) {
                    name = member.name
                    if let imageName = member.imageFileHash {
                        selectedAvatar = UserModel(familyMemberName: member.name, familyMemberImage: imageName)
                    }
                }
            }
        }
    }
    
    private func handleSave(trimmed: String) {
        if isSelf {
            familyStore.updatePendingSelfMemberName(trimmed)
            // Handle avatar assignment - upload in background without blocking UI
            // Priority:
            // 1. Selected local memoji (use storagePath, no upload)
            // 2. Custom memoji (use memoji-images storage path, no re-upload)
            if let selectedImageName = selectedAvatar?.image {
                // Check if it's a local memoji (starts with "memoji_")
                if selectedImageName.hasPrefix("memoji_") {
                    // Local memoji selected - use storagePath, no upload needed
                    Task {
                        let colorHex = selectedAvatar?.backgroundColor?.toHex()
                        await familyStore.setPendingSelfMemberAvatarFromMemoji(
                            storagePath: selectedImageName,
                            backgroundColorHex: colorHex
                        )
                    }
                } else {
                    // Legacy predefined avatar (shouldn't happen after migration, but handle gracefully)
                    if let assetImage = UIImage(named: selectedImageName) {
                        Task {
                            await familyStore.setPendingSelfMemberAvatar(image: assetImage, webService: webService)
                        }
                    } else {
                        familyStore.setPendingSelfMemberAvatar(imageName: selectedImageName)
                    }
                }
            } else if let storagePath = memojiStore.imageStoragePath, !storagePath.isEmpty {
                // Custom avatar from memojiStore - use memoji storage path directly
                Task {
                    await familyStore.setPendingSelfMemberAvatarFromMemoji(
                        storagePath: storagePath,
                        backgroundColorHex: memojiStore.backgroundColorHex
                    )
                }
            }
        } else {
            familyStore.updatePendingOtherMemberName(id: memberId, name: trimmed)
            // Handle avatar assignment - upload in background without blocking UI
            // Priority:
            // 1. Selected local memoji (use storagePath, no upload)
            // 2. Custom memoji (use memoji-images storage path, no re-upload)
            if let selectedImageName = selectedAvatar?.image {
                // Check if it's a local memoji (starts with "memoji_")
                if selectedImageName.hasPrefix("memoji_") {
                    // Local memoji selected - use storagePath, no upload needed
                    Task {
                        let colorHex = selectedAvatar?.backgroundColor?.toHex()
                        await familyStore.setAvatarForPendingOtherMemberFromMemoji(
                            id: memberId,
                            storagePath: selectedImageName,
                            backgroundColorHex: colorHex
                        )
                    }
                } else {
                    // Legacy predefined avatar (shouldn't happen after migration, but handle gracefully)
                    if let assetImage = UIImage(named: selectedImageName) {
                        Task {
                            await familyStore.setAvatarForPendingOtherMember(id: memberId, image: assetImage, webService: webService)
                        }
                    } else {
                        familyStore.setAvatarForPendingOtherMember(id: memberId, imageName: selectedImageName)
                    }
                }
            } else if let storagePath = memojiStore.imageStoragePath, !storagePath.isEmpty {
                // Custom avatar from memojiStore - use memoji storage path directly
                Task {
                    await familyStore.setAvatarForPendingOtherMemberFromMemoji(
                        id: memberId,
                        storagePath: storagePath,
                        backgroundColorHex: memojiStore.backgroundColorHex
                    )
                }
            }
        }
        // Call onSave immediately so sheet closes
        onSave()
    }
}
