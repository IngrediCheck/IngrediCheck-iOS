//
//  SetUpAvatarFor.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct SetUpAvatarFor: View {
    @Environment(FamilyStore.self) private var familyStore
    @Environment(WebService.self) private var webService
    @Environment(MemojiStore.self) private var memojiStore
    
    private var members: [FamilyMember] {
        guard let family = familyStore.family else { return [] }
        return [family.selfMember] + family.otherMembers
    }
    
    @State private var selectedMember: FamilyMember? = nil
    let nextPressed: () -> Void
    
    init(nextPressed: @escaping () -> Void = {}) {
        self.nextPressed = nextPressed
    }
    
    var body: some View {
        VStack(spacing: 24) {
            
            VStack(spacing: 10) {
                Text("Whom do you want to set up\nan avatar for?")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                
                Text("Choose a family member to start crafting their avatar")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(members) { member in
                        VStack(spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                // Member avatar view that loads actual memoji if available
                                SetUpAvatarMemberView(member: member)
                                    .grayscale(selectedMember?.id == member.id ? 0 : 1)
                                
                                if selectedMember?.id == member.id {
                                    Circle()
                                        .fill(Color(hex: "2C9C3D"))
                                        .frame(width: 16, height: 16)
                                        .overlay(
                                            Circle()
                                                .stroke(lineWidth: 1)
                                                .foregroundStyle(.white)
                                        )
                                        .overlay(
                                            Image("white-rounded-checkmark")
                                        )
                                        .offset(x: 0, y: -3)
                                }
                            }
                            
                            Text(member.name)
                                .font(ManropeFont.regular.size(10))
                                .foregroundStyle(.grayScale150)
                        }
                        .onTapGesture {
                            selectedMember = member
                        }
                    }
                }
                .padding(.leading, 20)
                .padding(.vertical, 6)
            }
            
            Button {
                guard let selected = selectedMember else {
                    print("[SetUpAvatarFor] Next tapped with no member selected, ignoring")
                    return
                }
                
                // Update display name for the selected member
                memojiStore.displayName = selected.name
                
                // Remember which member's avatar we are about to generate,
                // so that MeetYourAvatar can upload the image for this member.
                print("[SetUpAvatarFor] Next tapped, setting avatarTargetMemberId=\(selected.id), displayName=\(selected.name)")
                familyStore.avatarTargetMemberId = selected.id
                
                nextPressed()
            } label: {
                GreenCapsule(title: "Next")
                    .frame(width: 180)
            }
            .padding(.bottom, 8)
        }
        
        .padding(.bottom, 53)
        .padding(.top, 40)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}

/// Avatar view used in SetUpAvatarFor sheet to show actual member memoji avatars.
struct SetUpAvatarMemberView: View {
    let member: FamilyMember
    
    var body: some View {
        // Use centralized MemberAvatar component
        MemberAvatar.custom(member: member, size: 46, imagePadding: 0)
    }
}
