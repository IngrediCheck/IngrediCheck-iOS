//
//  MeetYourProfileView.swift
//  IngrediCheckPreview
//
//  Created to display the user's profile with editable name and avatar.
//

import SwiftUI

// MARK: - Meet Your Profile View

struct MeetYourProfileView: View {
    var onContinue: () -> Void
    let memberId: UUID?
    @Environment(FamilyStore.self) var familyStore
    @Environment(MemojiStore.self) var memojiStore
    @Environment(AppNavigationCoordinator.self) var coordinator
    @State private var primaryMemberName: String = ""
    @FocusState private var isEditingPrimaryName: Bool
    
    init(memberId: UUID? = nil, onContinue: @escaping () -> Void) {
        self.memberId = memberId
        self.onContinue = onContinue
    }
    
    private var isFromFamilyOverview: Bool {
        coordinator.currentCanvasRoute == .letsMeetYourIngrediFam
    }
    
    private var targetMember: FamilyMember? {
        if let memberId = memberId {
            // Find the specific member by ID
            if let family = familyStore.family {
                if family.selfMember.id == memberId {
                    return family.selfMember
                }
                return family.otherMembers.first { $0.id == memberId }
            } else {
                if familyStore.pendingSelfMember?.id == memberId {
                    return familyStore.pendingSelfMember
                }
                return familyStore.pendingOtherMembers.first { $0.id == memberId }
            }
        } else {
            // Default to self member if no memberId provided
            return familyStore.family?.selfMember ?? familyStore.pendingSelfMember
        }
    }
    
    private var isSelfMember: Bool {
        guard let targetMember = targetMember else { return true }
        if let family = familyStore.family {
            return targetMember.id == family.selfMember.id
        }
        return targetMember.id == familyStore.pendingSelfMember?.id
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Avatar Section
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let image = memojiStore.image {
                            // 1. Show the image that was JUST generated
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .background(Color(hex: memojiStore.backgroundColorHex ?? "#E0BBE4"))
                                .clipShape(Circle())
                        } else if let member = targetMember,
                                  let hash = member.imageFileHash, !hash.isEmpty {
                            // 2. Show the avatar from the member's data (saved or pending)
                            MemberAvatar.custom(member: member, size: 80, imagePadding: 0)
                        } else {
                            // 3. Default placeholder with curly-lady
                            ZStack {
                                Circle()
                                    .fill(Color(hex: (targetMember?.color ?? memojiStore.backgroundColorHex) ?? "#E0BBE4"))
                                    .frame(width: 80, height: 80)
                                
                                Image("curly-lady")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    
                    Button {
                         // Sync current name to store before generating
                         commitPrimaryName()
                         
                         // Navigation to avatar generation
                         memojiStore.displayName = primaryMemberName
                         
                         // Set the target member ID so handleAssignAvatar knows who to update
                         if let member = targetMember {
                             familyStore.avatarTargetMemberId = member.id
                         } else if isSelfMember {
                             // Create pending self member if none exists
                             familyStore.setPendingSelfMember(name: primaryMemberName)
                             familyStore.avatarTargetMemberId = familyStore.pendingSelfMember?.id
                         } else if let memberId = memberId {
                             // For other members, ensure they exist in pending
                             familyStore.avatarTargetMemberId = memberId
                         }
                         
                         memojiStore.previousRouteForGenerateAvatar = .meetYourProfile(memberId: memberId)
                         coordinator.navigateInBottomSheet(.generateAvatar)
                    } label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                            .overlay(
                                Image("pen-line")
                                    .resizable()
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(.grayScale100)
                            )
                    }
                    .offset(x: 4, y: 4)
                }
            }
            .padding(.top, 16)

            // Greeting Title
            HStack(spacing: 8) {
                Text("Hello,")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                
                HStack(spacing: 8) {
                    TextField("", text: $primaryMemberName)
                        .font(NunitoFont.bold.size(22))
                        .foregroundStyle(Color(hex: "#303030"))
                        .disableAutocorrection(true)
                        .focused($isEditingPrimaryName)
                        .submitLabel(.done)
                        .onSubmit { commitPrimaryName() }
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image("pen-line")
                        .resizable()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.grayScale100)
                        .onTapGesture { isEditingPrimaryName = true }
                }
                .padding(.leading, 8)
                .padding(.trailing, 5)
                .frame(height: 35)
                .frame(maxWidth: 250)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isEditingPrimaryName ? Color(hex: "#EEF5E3") : .white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#E3E3E3"), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
                .fixedSize(horizontal: true, vertical: false)
                .onTapGesture { isEditingPrimaryName = true }
                
                Text("!")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Description
            Text("We've created a profile name and avatar based on your preferences. You can edit the name or avatar anytime to make it truly yours.")
                .font(ManropeFont.medium.size(12))
                .foregroundStyle(.grayScale100)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            
            // Continue/Done Button
            Button(action: {
                commitPrimaryName()
                onContinue()
            }) {
                GreenCapsule(title: isFromFamilyOverview ? "Done" : "Continue", width: 159)
                    .frame(width: 159)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if let member = targetMember {
                // If it's the self member and "Just Me" flow, backend defaults the member name to "Me"
                // but the family name to "Bite Buddy". We should show "Bite Buddy" here.
                if isSelfMember, let family = familyStore.family,
                   member.name == "Me" && !family.name.isEmpty {
                    primaryMemberName = family.name
                } else {
                    primaryMemberName = member.name
                }
            } else {
                primaryMemberName = "Bite Buddy"
            }
        }
        .onChange(of: isEditingPrimaryName) { _, editing in
            if !editing {
                commitPrimaryName()
            }
        }
        .onChange(of: primaryMemberName) { oldValue, newValue in
            // Filter to letters and spaces only
            let filtered = newValue.filter { $0.isLetter || $0.isWhitespace }
            var finalized = filtered
            
            // Limit to 25 characters
            if finalized.count > 25 {
                finalized = String(finalized.prefix(25))
            }
            
            // Limit to max 3 words (max 2 spaces)
            let components = finalized.components(separatedBy: .whitespaces)
            if components.count > 3 {
                finalized = components.prefix(3).joined(separator: " ")
            }
            
            if finalized != newValue {
                primaryMemberName = finalized
            }
        }
    }
    
    private func commitPrimaryName() {
        let trimmed = primaryMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        Task { @MainActor in
            if let member = targetMember {
                if isSelfMember {
                    // Update self member
                    if let family = familyStore.family {
                        var me = family.selfMember
                        guard me.name != trimmed else { return }
                        me.name = trimmed
                        await familyStore.editMember(me)
                    } else if let pending = familyStore.pendingSelfMember {
                        if pending.name != trimmed {
                            familyStore.updatePendingSelfMemberName(trimmed)
                        }
                    } else {
                        familyStore.setPendingSelfMember(name: trimmed)
                    }
                } else {
                    // Update other member
                    if let family = familyStore.family, let existingMember = family.otherMembers.first(where: { $0.id == member.id }) {
                        var updatedMember = existingMember
                        guard updatedMember.name != trimmed else { return }
                        updatedMember.name = trimmed
                        await familyStore.editMember(updatedMember)
                    } else if let pendingMember = familyStore.pendingOtherMembers.first(where: { $0.id == member.id }) {
                        if pendingMember.name != trimmed {
                            familyStore.updatePendingOtherMemberName(id: member.id, name: trimmed)
                        }
                    }
                }
            } else if isSelfMember {
                // Create pending self member if none exists
                familyStore.setPendingSelfMember(name: trimmed)
            }
        }
    }
}

#Preview("Meet Your Profile View") {
    let familyStore = FamilyStore()
    let memojiStore = MemojiStore()
    
    // Set up mock memoji data for preview
    memojiStore.backgroundColorHex = "#E0BBE4"
    memojiStore.image = UIImage(systemName: "person.circle.fill")
    
    return MeetYourProfileView(onContinue: {})
        .environment(familyStore)
        .environment(memojiStore)
}
