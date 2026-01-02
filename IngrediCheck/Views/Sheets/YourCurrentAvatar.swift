//
//  YourCurrentAvatar.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct YourCurrentAvatar: View {
    @Environment(FamilyStore.self) private var familyStore
    @Environment(WebService.self) private var webService
    @Environment(MemojiStore.self) private var memojiStore
    
    let createNewPressed: () -> Void
    
    init(createNewPressed: @escaping () -> Void = {}) {
        self.createNewPressed = createNewPressed
    }
    
    private var currentMember: FamilyMember? {
        guard let family = familyStore.family else { return nil }
        
        // If a member was selected in SetUpAvatarFor, show that member's avatar
        if let targetMemberId = familyStore.avatarTargetMemberId {
            if targetMemberId == family.selfMember.id {
                return family.selfMember
            } else if let member = family.otherMembers.first(where: { $0.id == targetMemberId }) {
                return member
            }
        }
        
        // Otherwise, default to selfMember
        return family.selfMember
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Show actual member avatar
            if let member = currentMember {
                YourCurrentAvatarView(member: member)
                    .padding(.bottom, 26)
            } else {
                Circle()
                    .fill(Color(hex: "#D9D9D9"))
                    .frame(width: 120, height: 120)
                    .padding(.bottom, 26)
            }
            
            Text("Here's your current avatar. would you like to make a new one?")
                .font(NunitoFont.bold.size(20))
                .multilineTextAlignment(.center)
                .padding(.bottom, 23)
            
            Button {
                // Update display name to current member's name before creating new avatar
                if let member = currentMember {
                    memojiStore.displayName = member.name
                }
                createNewPressed()
            } label: {
                GreenCapsule(title: "Create New")
                    .frame(width: 159)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 64)
        .padding(.top, 40)
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}


/// Large avatar view (120x120) used in YourCurrentAvatar sheet to show the member's current memoji.
struct YourCurrentAvatarView: View {
    let member: FamilyMember
    
    var body: some View {
        // Use centralized MemberAvatar component
        MemberAvatar.large(member: member)
    }
}
