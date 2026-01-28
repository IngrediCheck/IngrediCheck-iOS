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
    @Environment(FoodNotesStore.self) private var foodNotesStore: FoodNotesStore?
    @EnvironmentObject private var store: Onboarding

    @State var selectedFamilyMember: UserModel? = nil
    
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
            // Initialize selection based on familyStore.selectedMemberId if set,
            // otherwise default to "Everyone"
            if selectedFamilyMember == nil {
                if let memberId = familyStore.selectedMemberId {
                    // A specific member was selected (e.g., from Food Notes filter)
                    // Find and select that member
                    if let matchingMember = familyMembersList.first(where: { $0.id == memberId.uuidString }) {
                        selectedFamilyMember = matchingMember
                    } else {
                        // Fallback to "Everyone" if member not found
                        selectedFamilyMember = UserModel(
                            id: "everyone",
                            familyMemberName: "Everyone",
                            familyMemberImage: "Everyone",
                            backgroundColor: .clear
                        )
                    }
                } else {
                    // No specific member selected, default to "Everyone"
                    selectedFamilyMember = UserModel(
                        id: "everyone",
                        familyMemberName: "Everyone",
                        familyMemberImage: "Everyone",
                        backgroundColor: .clear
                    )
                }
            }
        }
    }
    
    @MainActor
    func selectFamilyMember(ele: UserModel) async {
        Log.debug("FamilyCarouselView", "selectFamilyMember: Tapped member name=\(ele.name), id=\(ele.id)")
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedFamilyMember = ele
        }
        
        // "everyone" is our sentinel ID for the family-level note
        let memberId: String? = (ele.id == "everyone") ? nil : ele.id
        
        // Keep FamilyStore in sync so other components (like EditableCanvasView)
        // know whether we are editing at family level or for a specific member.
        if let memberId, let uuid = UUID(uuidString: memberId) {
            Log.debug("FamilyCarouselView", "selectFamilyMember: Setting FamilyStore.selectedMemberId=\(uuid)")
            familyStore.selectedMemberId = uuid
        } else {
            Log.debug("FamilyCarouselView", "selectFamilyMember: Setting FamilyStore.selectedMemberId=nil (Everyone)")
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
    
    let memberIdentifier: String // "everyone" or member UUID string
    let name: String?
    let color: Color
    let isSelected: Bool
    
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
                    // Individual member - use centralized MemberAvatar component
                    if let member = resolvedMember {
                        MemberAvatar.custom(member: member, size: 46, imagePadding: 0)
                    } else {
                        // Fallback for "everyone" case
                        Circle()
                            .fill(color)
                            .frame(width: 46, height: 46)
                            .overlay(
                                Circle()
                                    .stroke(lineWidth: 1)
                                    .foregroundStyle(Color.white)
                            )
                    }
                }
            }
            
            if let name = name {
                Text(name)
                    .font(isSelected ? ManropeFont.bold.size(10) : ManropeFont.regular.size(10))
                    .foregroundStyle(isSelected ? Color(hex: "91B640") : .grayScale130)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
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
}

#Preview {
    let webService = WebService()
    let onboarding = Onboarding(onboardingFlowtype: .family)
    let foodNotesStore = FoodNotesStore(webService: webService, onboardingStore: onboarding)

    // Create mock family with multiple members
    let familyStore = FamilyStore()
    let mockFamily = Family(
        name: "Smith Family",
        selfMember: FamilyMember(
            id: UUID(),
            name: "Alex",
            color: "#FFB3BA",
            joined: true,
            imageFileHash: "memoji_1"
        ),
        otherMembers: [
            FamilyMember(
                id: UUID(),
                name: "Jordan",
                color: "#BAFFC9",
                joined: true,
                imageFileHash: "memoji_2"
            ),
            FamilyMember(
                id: UUID(),
                name: "Taylor",
                color: "#BAE1FF",
                joined: false,
                imageFileHash: "memoji_3"
            ),
            FamilyMember(
                id: UUID(),
                name: "Sam",
                color: "#E0BBE4",
                joined: true,
                imageFileHash: "memoji_4"
            )
        ],
        version: 1
    )
    familyStore.setMockFamilyForPreview(mockFamily)

    return FamilyCarouselView()
        .environment(familyStore)
        .environmentObject(onboarding)
        .environment(webService)
        .environment(foodNotesStore)
}
