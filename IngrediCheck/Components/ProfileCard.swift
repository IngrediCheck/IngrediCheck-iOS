//
//  ProfileCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/10/25.
//

import SwiftUI
	
struct ProfileCard: View {
    @Environment(FamilyStore.self) private var familyStore
    
    @State var isProfileCompleted: Bool = false
    
    private var selfMember: FamilyMember? {
        return familyStore.family?.selfMember
    }
    
    var body: some View {
        ZStack {
            
            if isProfileCompleted {
                Circle()
                    .frame(width: 66, height: 66)
                    .foregroundStyle(Color(hex: "#ABAAAA").opacity(0.1))
                    .shadow(color: Color(hex: "#ECECEC"), radius: 9, x: 0, y: 0)
                    
                
                Circle()
                    .frame(width: 55, height: 55)
                    .foregroundStyle(.grayScale10)
                    .shadow(color: Color(hex: "#FBFBFB"), radius: 9, x: 0, y: 0)
                    
                
                if let member = selfMember {
                    ProfileCardAvatarView(member: member, size: 55)
                } else {
                    Image("profile-ritika")
                        .resizable()
                        .frame(width: 55, height: 55)
                        .clipShape(.circle)
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
    @Environment(WebService.self) private var webService
    let member: FamilyMember
    let size: CGFloat
    
    @State private var avatarImage: UIImage? = nil
    @State private var loadedHash: String? = nil
    
    var body: some View {
        Group {
            if let avatarImage {
                // Show loaded memoji avatar
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Fallback: first letter of name on colored background
                Circle()
                    .fill(Color(hex: member.color))
                    .frame(width: size, height: size)
                    .overlay {
                        Text(String(member.name.prefix(1)))
                            .font(NunitoFont.semiBold.size(size * 0.4))
                            .foregroundStyle(.white)
                    }
            }
        }
        .task(id: member.imageFileHash) {
            await loadAvatarIfNeeded()
        }
    }
    
    @MainActor
    private func loadAvatarIfNeeded() async {
        guard let hash = member.imageFileHash, !hash.isEmpty else {
            avatarImage = nil
            loadedHash = nil
            return
        }
        
        // Skip if already loaded for this hash
        if loadedHash == hash, avatarImage != nil {
            return
        }
        
        // 1) Try local asset
        if let local = UIImage(named: hash) {
            avatarImage = local
            loadedHash = hash
            print("[ProfileCardAvatarView] ✅ Loaded local avatar for \(member.name)")
            return
        }
        
        print("[ProfileCardAvatarView] Loading remote avatar for \(member.name), imageFileHash=\(hash)")
        do {
            let uiImage = try await webService.fetchImage(
                imageLocation: .imageFileHash(hash),
                imageSize: .small
            )
            avatarImage = uiImage
            loadedHash = hash
            print("[ProfileCardAvatarView] ✅ Loaded avatar for \(member.name)")
        } catch {
            print("[ProfileCardAvatarView] ❌ Failed to load avatar for \(member.name): \(error.localizedDescription)")
        }
    }
}

#Preview {
    ProfileCard()
}
