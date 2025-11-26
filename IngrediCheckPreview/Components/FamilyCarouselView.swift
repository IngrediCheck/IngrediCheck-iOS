//
//  FamilyCarouselView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 01/10/25.
//

import SwiftUI

struct FamilyCarouselView: View {
    
    @State var familyMembersList: [UserModel] = [
        UserModel(familyMemberName: "Everyone", familyMemberImage: "Everyone", backgroundColor: .clear),
        
        UserModel(familyMemberName: "Ritika Raj", familyMemberImage: "Ritika Raj", backgroundColor: Color(hex: "DCC7F6")),
        UserModel(familyMemberName: "Neha", familyMemberImage: "Neha", backgroundColor: Color(hex: "F9C6D0")),
        UserModel(familyMemberName: "Aarnav", familyMemberImage: "Aarnav", backgroundColor: Color(hex: "FFF6B3")),
        UserModel(familyMemberName: "Harsh", familyMemberImage: "Harsh", backgroundColor: Color(hex: "FFD9B5")),
        UserModel(familyMemberName: "Grandpa", familyMemberImage: "Grandpa", backgroundColor: Color(hex: "BFF0D4")),
        UserModel(familyMemberName: "Grandma", familyMemberImage: "Grandma", backgroundColor: Color(hex: "A7D8F0"))
    ]
    
    @State var selectedFamilyMember: UserModel? = UserModel(familyMemberName: "Everyone", familyMemberImage: "Everyone", backgroundColor: .clear)
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(familyMembersList, id: \.id) { ele in
                    circleImage(
                        image: ele.image,
                        name: ele.name,
                        color: ele.backgroundColor ?? .clear,
                        isSelected: ele.name == selectedFamilyMember?.name
                    )
                    .onTapGesture {
                        selectFamilyMember(ele: ele)
                    }
                }
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
                            Image(image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 46, height: 46)
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
}
