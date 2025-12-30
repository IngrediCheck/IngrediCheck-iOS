//
//  FamilyCarouselView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 01/10/25.
//

import SwiftUI

struct FamilyCarouselView: View {
    @Environment(FamilyStore.self) private var familyStore
    @Environment(WebService.self) private var webService
    @EnvironmentObject private var store: Onboarding
    
    @State var selectedFamilyMember: UserModel? = nil
    @State private var foodNotesStore: FoodNotesStore?
    
    // Convert FamilyMember objects to UserModel format
    private var familyMembersList: [UserModel] {
        var members: [UserModel] = []
        
        // Always include "Everyone" as the first option
        members.append(
            UserModel(
                id: "everyone",
                familyMemberName: "Everyone",
                familyMemberImage: "Everyone",
                backgroundColor: .clear
            )
        )
        
        // Add actual family members from FamilyStore
        if let family = familyStore.family {
            // Add self member
            members.append(
                UserModel(
                    id: family.selfMember.id.uuidString,
                    familyMemberName: family.selfMember.name,
                    familyMemberImage: family.selfMember.name, // Use name as image identifier
                    backgroundColor: Color(hex: family.selfMember.color)
                )
            )
            
            // Add other members
            for otherMember in family.otherMembers {
                members.append(
                    UserModel(
                        id: otherMember.id.uuidString,
                        familyMemberName: otherMember.name,
                        familyMemberImage: otherMember.name, // Use name as image identifier
                        backgroundColor: Color(hex: otherMember.color)
                    )
                )
            }
        }
        
        return members
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(familyMembersList, id: \.id) { ele in
                    FamilyCarouselMemberAvatarView(
                        memberIdentifier: ele.id,
                        name: ele.name,
                        color: ele.backgroundColor ?? .clear,
                        isSelected: ele.id == selectedFamilyMember?.id
                    )
                    .onTapGesture {
                        Task {
                            await selectFamilyMember(ele: ele)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Initialize FoodNotesStore with environment values
            if foodNotesStore == nil {
                foodNotesStore = FoodNotesStore(webService: webService, onboardingStore: store)
            }
            
            // Initialize selection to "Everyone" if not already set
            // But don't automatically load food notes - let user explicitly select a member
            if selectedFamilyMember == nil {
                selectedFamilyMember = UserModel(
                    id: "everyone",
                    familyMemberName: "Everyone",
                    familyMemberImage: "Everyone",
                    backgroundColor: .clear
                )
                
                // Set FamilyStore.selectedMemberId to nil for "Everyone" but don't load food notes
                // This ensures the UI shows "Everyone" as selected without breaking the flow
                familyStore.selectedMemberId = nil
            }
        }
    }
    
    @MainActor
    func selectFamilyMember(ele: UserModel) async {
        print("[FamilyCarouselView] selectFamilyMember: Tapped member name=\(ele.name), id=\(ele.id)")
        selectedFamilyMember = ele
        
        // "everyone" is our sentinel ID for the family-level note
        let memberId: String? = (ele.id == "everyone") ? nil : ele.id
        
        // Keep FamilyStore in sync so other components (like EditableCanvasView)
        // know whether we are editing at family level or for a specific member.
        if let memberId, let uuid = UUID(uuidString: memberId) {
            print("[FamilyCarouselView] selectFamilyMember: Setting FamilyStore.selectedMemberId=\(uuid)")
            familyStore.selectedMemberId = uuid
        } else {
            print("[FamilyCarouselView] selectFamilyMember: Setting FamilyStore.selectedMemberId=nil (Everyone)")
            familyStore.selectedMemberId = nil
        }
        
        // Load food notes for the selected member using FoodNotesStore
        if let memberId = memberId {
            await foodNotesStore?.loadFoodNotesForMember(memberId: memberId)
        } else {
            await foodNotesStore?.loadFoodNotesForFamily()
        }
    }
}

// MARK: - Family Carousel Member Avatar View

/// Avatar view used in FamilyCarouselView to show actual member memoji avatars.
struct FamilyCarouselMemberAvatarView: View {
    @Environment(FamilyStore.self) private var familyStore
    @Environment(WebService.self) private var webService
    
    let memberIdentifier: String // "everyone" or member UUID string
    let name: String?
    let color: Color
    let isSelected: Bool
    
    @State private var avatarImage: UIImage? = nil
    @State private var loadedHash: String? = nil
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    Circle()
                        .strokeBorder(Color(hex: "91B640"), lineWidth: 2)
                        .frame(width: 52, height: 52)
                }
                
                if memberIdentifier == "everyone" {
                    // "Everyone" option
                    Circle()
                        .frame(width: 46, height: 46)
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "FFC552"), Color(hex: "FFAA28")], startPoint: .top, endPoint: .bottom)
                        )
                        .overlay {
                            Image("Everyone")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 28, height: 28)
                        }
                } else {
                    // Individual member - show avatar with background color circle, or fallback with initial letter
                    Circle()
                        .fill(color)
                        .frame(width: 46, height: 46)
                        .overlay {
                            if let avatarImage = avatarImage {
                                // Show transparent PNG memoji avatar over colored background
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 46, height: 46)
                                    .clipShape(Circle())
                            } else if let member = resolvedMember {
                                // Fallback: initial letter
                                Text(String(member.name.prefix(1)))
                                    .font(NunitoFont.semiBold.size(14))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            Circle()
                                .stroke(lineWidth: 1)
                                .foregroundStyle(Color.white)
                        )
                }
            }
            
            if let name = name {
                Text(name)
                    .font(ManropeFont.regular.size(10))
                    .foregroundStyle(isSelected ? Color(hex: "91B640") : .grayScale130)
            }
        }
        .task(id: memberIdentifier) {
            await loadAvatarIfNeeded()
        }
    }
    
    private var resolvedMember: FamilyMember? {
        guard memberIdentifier != "everyone",
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
        guard memberIdentifier != "everyone",
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
        
        print("[FamilyCarouselMemberAvatarView] Loading avatar for \(member.name), imageFileHash=\(hash)")
        do {
            let uiImage = try await webService.fetchImage(
                imageLocation: .imageFileHash(hash),
                imageSize: .small
            )
            avatarImage = uiImage
            loadedHash = hash
            print("[FamilyCarouselMemberAvatarView] ✅ Loaded avatar for \(member.name)")
        } catch {
            print("[FamilyCarouselMemberAvatarView] ❌ Failed to load avatar for \(member.name): \(error.localizedDescription)")
        }
    }
}

#Preview {
    FamilyCarouselView()
        .environment(FamilyStore())
}
