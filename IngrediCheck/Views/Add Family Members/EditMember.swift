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
        UserModel(familyMemberName: "Neha", familyMemberImage: "image-bg5", backgroundColor: Color(hex: "F9C6D0")),
        UserModel(familyMemberName: "Aarnav", familyMemberImage: "image-bg4", backgroundColor: Color(hex: "FFF6B3")),
        UserModel(familyMemberName: "Harsh", familyMemberImage: "image-bg1", backgroundColor: Color(hex: "FFD9B5")),
        UserModel(familyMemberName: "Grandpa", familyMemberImage: "image-bg3", backgroundColor: Color(hex: "BFF0D4")),
        UserModel(familyMemberName: "Grandma", familyMemberImage: "image-bg2", backgroundColor: Color(hex: "A7D8F0"))
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
                            coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
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
                        .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
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

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            Button {
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
                        .padding(.horizontal, 20)
                    }
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
            // Priority: selected predefined avatar > custom avatar from memojiStore
            if let selectedImageName = selectedAvatar?.image,
               let assetImage = UIImage(named: selectedImageName) {
                // Predefined avatar selected - upload it in background
                Task {
                    await familyStore.setPendingSelfMemberAvatar(image: assetImage, webService: webService)
                }
            } else if let customImage = memojiStore.image {
                // Custom avatar from memojiStore - upload it in background with memoji background color
                Task {
                    await familyStore.setPendingSelfMemberAvatar(
                        image: customImage,
                        webService: webService,
                        backgroundColorHex: memojiStore.backgroundColorHex
                    )
                }
            } else if let selectedImageName = selectedAvatar?.image {
                // Fallback to old method if image can't be loaded
                familyStore.setPendingSelfMemberAvatar(imageName: selectedImageName)
            }
        } else {
            familyStore.updatePendingOtherMemberName(id: memberId, name: trimmed)
            // Handle avatar assignment - upload in background without blocking UI
            // Priority: selected predefined avatar > custom avatar from memojiStore
            if let selectedImageName = selectedAvatar?.image,
               let assetImage = UIImage(named: selectedImageName) {
                // Predefined avatar selected - upload it in background
                Task {
                    await familyStore.setAvatarForPendingOtherMember(id: memberId, image: assetImage, webService: webService)
                }
            } else if let customImage = memojiStore.image {
                // Custom avatar from memojiStore - upload it in background with memoji background color
                Task {
                    await familyStore.setAvatarForPendingOtherMember(
                        id: memberId,
                        image: customImage,
                        webService: webService,
                        backgroundColorHex: memojiStore.backgroundColorHex
                    )
                }
            } else if let selectedImageName = selectedAvatar?.image {
                // Fallback to old method if image can't be loaded
                familyStore.setAvatarForPendingOtherMember(id: memberId, imageName: selectedImageName)
            }
        }
        // Call onSave immediately so sheet closes
        onSave()
    }
}
