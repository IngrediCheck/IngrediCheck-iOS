//
//  FamilyCarouselView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 01/10/25.
//

import SwiftUI

struct FamilyCarouselView: View {
    @Environment(FamilyStore.self) private var familyStore
    
    @State var selectedFamilyMember: UserModel? = UserModel(familyMemberName: "Everyone", familyMemberImage: "Everyone", backgroundColor: .clear)
    
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
                    circleImage(
                        image: ele.image,
                        name: ele.name,
                        color: ele.backgroundColor ?? .clear,
                        isSelected: ele.id == selectedFamilyMember?.id
                    )
                    .onTapGesture {
                        selectFamilyMember(ele: ele)
                    }
                }
            }
        }
        .onAppear {
            // Initialize selection to "Everyone" if not already set
            if selectedFamilyMember == nil {
                selectedFamilyMember = UserModel(
                    id: "everyone",
                    familyMemberName: "Everyone",
                    familyMemberImage: "Everyone",
                    backgroundColor: .clear
                )
            }
        }
    }
    
    func selectFamilyMember(ele: UserModel) {
        selectedFamilyMember = ele
    }
}

struct circleImage: View {

    let image: String
    let name: String?
    let color: Color
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            if name == "Everyone" {
                ZStack {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color(hex: "91B640"), lineWidth: 2)
                            .frame(width: 52, height: 52)
                    }
                    
                    Circle()
                        .frame(width: 46, height: 46)
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "FFC552"), Color(hex: "FFAA28")], startPoint: .top, endPoint: .bottom)
                        )
                        .overlay(
                            Image(image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 28, height: 28)
                        )
                }
            } else {
                ZStack {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color(hex: "91B640"), lineWidth: 2)
                            .frame(width: 52, height: 52)
                    }
                    
                    Circle()
                        .frame(width: 46, height: 46)
                        .foregroundStyle(color)
                        .overlay(
                            Text(String((name ?? "").prefix(1)))
                                .font(NunitoFont.semiBold.size(14))
                                .foregroundStyle(.white)
                        )
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
    }
}

#Preview {
    FamilyCarouselView()
        .environment(FamilyStore())
}
