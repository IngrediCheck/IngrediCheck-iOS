//
//  ProfileCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/10/25.
//

import SwiftUI
	
struct ProfileCard: View {
    @Environment(FamilyStore.self) private var familyStore
    
    @State var isProfileCompleted: Bool = true
    
    private var selfMember: FamilyMember? {
        return familyStore.family?.selfMember
    }
    
    var body: some View {
        ZStack {
            
            if isProfileCompleted {
                if let member = selfMember {
                    ProfileCardAvatarView(member: member, size: 55)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 4)
                        )
                } else {
                    Image("memoji_4")
                        .resizable()
                        .frame(width: 55, height: 55)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 4)
                        )
                }
            } else {
                // the below component is only for background shadow as this is in zstack so for shadow this component is placed on the back of the circle so that the shadow should not overlap the circle
                Text("611")
                    .font(NunitoFont.regular.size(12))
                    .frame(height: 9.86)
                    .foregroundStyle(.grayScale10)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 62)
                            .foregroundStyle(
                                .primary800.gradient.shadow(
                                    .inner(color: Color(hex: "#DAFF67").opacity(0.25), radius: 4, x: 1, y: 2.5)
                                )
                                .shadow(
                                    .drop(color: Color(hex: "C5C5C5"), radius: 3.4, x: 0, y: 4)
                                )
                            )
                    )
                    .padding(.top, 55)
                
                Circle()
                    .frame(width: 66, height: 66)
                    .foregroundStyle(.grayScale30)
                    .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
                    .overlay(
                        Circle()
                            .stroke(lineWidth: 0.5)
                            .foregroundStyle(.grayScale80)
                            .overlay(
                                Circle()
                                    .trim(from: 0, to: 0.6)
                                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                    .foregroundStyle(.primary700)
                                    .rotationEffect(.degrees(90))
                            )
                    )
                
                Circle()
                    .foregroundColor(.grayScale10)
                    .frame(width: 47, height: 47)
                    .shadow(color: Color(hex: "FBFBFB"), radius: 9, x: 0, y: 0)
                    .overlay {
                        if let member = selfMember {
                            ProfileCardAvatarView(member: member, size: 38)
                        } else {
                            Image("profile-ritika")
                                .resizable()
                                .frame(width: 38, height: 38)
                        }
                    }
                    .clipShape(.circle)
                
                Text("60%")
                    .font(NunitoFont.regular.size(12))
                    .frame(height: 9.86)
                    .foregroundStyle(.grayScale10)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 62)
                            .foregroundStyle(
                                .primary800.gradient.shadow(
                                    .inner(color: Color(hex: "#DAFF67").opacity(0.5), radius: 2, x: 0, y: 3)
                                )
                            )
                    )
                    .padding(.top, 60)
            }
        }
    }
}

// MARK: - Profile Card Avatar View

/// Avatar view used in ProfileCard to show the self member's memoji avatar.
struct ProfileCardAvatarView: View {
    let member: FamilyMember
    let size: CGFloat
    
    var body: some View {
        // Use centralized MemberAvatar component
        MemberAvatar.custom(member: member, size: size, imagePadding: 0)
    }
}

#Preview("ProfileCardAvatarView") {
    let sampleMember = FamilyMember(
        id: UUID(),
        name: "John Doe",
        color: "#91B640",
        joined: true,
        imageFileHash: "memoji_4",
        invitePending: nil
    )
    
    HStack(spacing: 20) {
        ProfileCardAvatarView(member: sampleMember, size: 38)
            .overlay(
                Circle().stroke(Color.white, lineWidth: 4)
            )

        ProfileCardAvatarView(member: sampleMember, size: 55)
            .overlay(
                Circle().stroke(Color.white, lineWidth: 4)
            )

        ProfileCardAvatarView(member: sampleMember, size: 66)
            .overlay(
                Circle().stroke(Color.white, lineWidth: 4)
            )

    }
    .padding()
    .background(Color.grayScale30)
    .environment(WebService())
}

#Preview {
    ZStack {
        
        Color.grayScale30
        
        ProfileCard()
            .environment(FamilyStore())
    }
}
