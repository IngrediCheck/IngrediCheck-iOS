//
//  IngredientsChips.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import SwiftUI

struct IngredientsChips: View {
    var title: String = "Peanuts"
    @State var bgColor: Color? = nil
    var fontColor: String = "000000"
    var fontSize: CGFloat = 12
    var fontWeight: Font.Weight = .regular
    var image: String? = nil
    var familyList: [String] = [] // Can be "Everyone" or member IDs (UUID strings)
    var onClick: (() -> Void)? = nil
    var isSelected: Bool = false
    var outlined: Bool = true
    
    @Environment(FamilyStore.self) private var familyStore
    @Environment(WebService.self) private var webService
    
    var body: some View {
        Button {
            onClick?()
        } label: {
            HStack(spacing: 8) {
                if let image = image {
                    Text(image)
                        .font(.system(size: 18))
                        .frame(width: 24, height: 24)
                }
                
                Text(familyList.isEmpty ? title : String(title.prefix(25)) + (title.count > 25 ? "..." : ""))
                    .font(ManropeFont.medium.size(14))
                    .foregroundStyle(isSelected ? .primary100 : Color(hex: fontColor))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if !familyList.isEmpty {
                    HStack(spacing: -7) {
                        ForEach(familyList.prefix(4), id: \.self) { memberIdentifier in
                            ChipMemberAvatarView(memberIdentifier: memberIdentifier)
                        }
                    }
                }
            }
            .padding(.vertical, (image != nil) ? 6 : 7.5)
            .padding(.trailing, !familyList.isEmpty ? 8 : 16)
            .padding(.leading, (image != nil) ? 12 : 16)
            .background(
                (bgColor != nil)
                ? LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: bgColor ?? .white, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                : isSelected
                    ? LinearGradient(
                        colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    : LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                , in: .capsule
            )
            .overlay(
                Capsule()
                    .stroke(lineWidth: (isSelected || outlined == false) ? 0 : 1)
                    .foregroundStyle(.grayScale60)
            )
        }
    }
    
    // MARK: - Chip Member Avatar View
    
    /// Small avatar (24x24) used on chips to show which member selected an item.
    /// Shows the member's memoji if imageFileHash is present, otherwise shows
    /// "Everyone" icon or the first letter of their name.
    struct ChipMemberAvatarView: View {
        @Environment(FamilyStore.self) private var familyStore
        @Environment(WebService.self) private var webService
        
        let memberIdentifier: String // "Everyone" or member UUID string
        
        @State private var avatarImage: UIImage? = nil
        @State private var loadedHash: String? = nil
        
        var body: some View {
            ZStack {
                // Base colored circle
                Circle()
                    .stroke(lineWidth: 1)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Color(hex: "#B6B6B6"))
                    .background(circleBackgroundColor)
                
                if memberIdentifier == "Everyone" {
                    // Show "Everyone" icon
                    Image("Everyone")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                } else if let avatarImage {
                    // Show loaded memoji avatar
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                } else if let member = resolvedMember {
                    // Fallback: first letter of name
                    Text(String(member.name.prefix(1)))
                        .font(NunitoFont.semiBold.size(10))
                        .foregroundStyle(.white)
                }
            }
            .task(id: memberIdentifier) {
                await loadAvatarIfNeeded()
            }
        }
        
        private var circleBackgroundColor: Color {
            if memberIdentifier == "Everyone" {
                return Color(hex: "#D9D9D9")
            }
            if let member = resolvedMember {
                return Color(hex: member.color)
            }
            return Color(hex: "#D9D9D9")
        }
        
        private var resolvedMember: FamilyMember? {
            guard memberIdentifier != "Everyone",
                  let uuid = UUID(uuidString: memberIdentifier),
                  let family = familyStore.family else {
                return nil
            }
            
            if uuid == family.selfMember.id {
                return family.selfMember
            }
            return family.otherMembers.first { $0.id == uuid }
        }
        
        @MainActor
        private func loadAvatarIfNeeded() async {
            guard memberIdentifier != "Everyone",
                  let member = resolvedMember else {
                avatarImage = nil
                loadedHash = nil
                return
            }
            
            guard let hash = member.imageFileHash, !hash.isEmpty else {
                avatarImage = nil
                loadedHash = nil
                return
            }
            
            // Skip if already loaded for this hash
            if loadedHash == hash, avatarImage != nil {
                return
            }
            
            print("[IngredientsChips.ChipMemberAvatarView] Loading avatar for \(member.name), imageFileHash=\(hash)")
            do {
                let uiImage = try await webService.fetchImage(
                    imageLocation: .imageFileHash(hash),
                    imageSize: .small
                )
                avatarImage = uiImage
                loadedHash = hash
                print("[IngredientsChips.ChipMemberAvatarView] ✅ Loaded avatar for \(member.name)")
            } catch {
                print("[IngredientsChips.ChipMemberAvatarView] ❌ Failed to load avatar for \(member.name): \(error.localizedDescription)")
            }
        }
    }

}

#Preview {
    VStack {
        IngredientsChips(
            title: "Peanuts",
            image: "🥜"
        )
        IngredientsChips(
            title: "Sellfish",
            image: "🦐"
        )
        IngredientsChips(
            title: "Wheat",
            image: "🌾"
        )
        IngredientsChips(
            title: "Sesame",
            image: "❤️"
        )
        IngredientsChips(title: "India & South Asia")
        IngredientsChips(
            title: "Peanuts",
            image: "🥜",
            familyList: ["image 1", "image 2", "image 3"]
        )
    }
    
}
