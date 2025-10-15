//
//  FamilyCarouselView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 01/10/25.
//

import SwiftUI

struct FamilyCarouselView: View {
    
    @State var familyMembersList: [UserModel] = [
        
        UserModel(familyMemberName: "Ritika Raj", familyMemberImage: "Ritika Raj", backgroundColor: Color(hex: "DCC7F6")),
        UserModel(familyMemberName: "Neha", familyMemberImage: "Neha", backgroundColor: Color(hex: "F9C6D0")),
        UserModel(familyMemberName: "Aarnav", familyMemberImage: "Aarnav", backgroundColor: Color(hex: "FFF6B3")),
        UserModel(familyMemberName: "Harsh", familyMemberImage: "Harsh", backgroundColor: Color(hex: "FFD9B5")),
        UserModel(familyMemberName: "Grandpa", familyMemberImage: "Grandpa", backgroundColor: Color(hex: "BFF0D4")),
        UserModel(familyMemberName: "Grandma", familyMemberImage: "Grandma", backgroundColor: Color(hex: "A7D8F0"))
    ]
    
    @State var selectedFamilyMember: UserModel? = UserModel(familyMemberName: "Everyone", familyMemberImage: "Everyone", backgroundColor: .clear)
    
    var body: some View {
        HStack(spacing: 0) {
            VStack {
                ZStack {
                    
                    if selectedFamilyMember?.name == "Everyone" {
                        Circle()
                            .stroke(lineWidth: 2)
                            .foregroundStyle(Color(hex: "91B640"))
                            .frame(width: 46, height: 46)
                            .shadow(color: Color(hex: "B2B2B2"), radius: 9.6, x: 0, y: 0)
                        
                        Circle()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(
                                LinearGradient(colors: [Color(hex: "FFC552"), Color(hex: "FFAA28")], startPoint: .top, endPoint: .bottom)
                            )
                            
                        
                        Image("Everyone")
                            .resizable()
                            .frame(width: 26, height: 26)
                    } else {
                        Circle()
                            .stroke(lineWidth: 2)
                            .foregroundStyle(Color(hex: "91B640"))
                            .frame(width: 46, height: 46)
                        
                        Circle()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(selectedFamilyMember?.backgroundColor ?? .gray)
                        
                        Image(selectedFamilyMember?.image ?? "Everyone")
                            .resizable()
                            .frame(width: 40, height: 40)
                    }
                }
                
                Text(selectedFamilyMember?.name ?? "")
                    .font(ManropeFont.semiBold.size(10))
                    .foregroundStyle(.primary700)
            }
            
            RoundedRectangle(cornerRadius: 20)
                .frame(width: 1, height: 62)
                .foregroundStyle(
                    LinearGradient(colors: [Color(hex: "E3E3E3").opacity(0.2), Color(hex: "E6E6E6"), Color(hex: "E3E3E3").opacity(0.2)], startPoint: .top, endPoint: .bottom)
                )
                .padding(.leading, 11)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(familyMembersList, id: \.id) { ele in
                        circleImage(image: ele.image, name: ele.name, color: ele.backgroundColor ?? .clear)
                            .onTapGesture {
                                selectFamilyMember(ele: ele)
                            }
                    }
                }
                .padding(.horizontal, 11)
            }
        }
    }
    
    func selectFamilyMember(ele: UserModel) {
        let temp = selectedFamilyMember
        selectedFamilyMember = ele
        withAnimation(.linear) {
            familyMembersList.removeAll{ $0.name == ele.name }
        }
        if let temp {
            withAnimation(.linear) {
                familyMembersList.append(temp)
            }
        }
    }
    
    
    struct circleImage: View {

        let image: String
        let name: String
        let color: Color
        
        var body: some View {
            VStack(spacing: 4) {
                if name == "Everyone" {
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
                } else {
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
                
                
                Text(name)
                    .font(ManropeFont.regular.size(10))
                    .foregroundStyle(.grayScale130)
            }
        }
    }
}

#Preview {
    FamilyCarouselView()
        .padding(.leading, 25)
}
