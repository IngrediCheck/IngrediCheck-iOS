//
//  FamilyCarouselView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 01/10/25.
//

import SwiftUI

struct FamilyCarouselView: View {
    
    @State var familyMembersList: [FamilyMemberModel] = [
        FamilyMemberModel(familyMemberName: "Everyone", familyMemberImage: "Everyone"),
        FamilyMemberModel(familyMemberName: "Ritika Raj", familyMemberImage: "Ritika Raj"),
        FamilyMemberModel(familyMemberName: "Neha", familyMemberImage: "Neha"),
        FamilyMemberModel(familyMemberName: "Aarnav", familyMemberImage: "Aarnav"),
        FamilyMemberModel(familyMemberName: "Harsh", familyMemberImage: "Harsh"),
        FamilyMemberModel(familyMemberName: "Grandpa", familyMemberImage: "Grandpa"),
        FamilyMemberModel(familyMemberName: "Grandma", familyMemberImage: "Grandma")
    ]
    
    @State var selectedFamilyMember: FamilyMemberModel? = nil
    
    var body: some View {
        ZStack(alignment: .trailing) {
            Image("familyCarouselBackground")
                .resizable()
                .frame(height: 79)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(familyMembersList) { ele in
                        Button {
                            selectFamilyMember(ele: ele)
                        } label: {
                            circleImage(image: ele.familyMemberImage, name: ele.familyMemberName)
                        }
                    }
                }
                .padding(.trailing, 12)
            }
            .background(Color(hex: "#ECECEC"), in: RoundedRectangle(cornerRadius: 16))
            .frame(height: 79)
            .frame(width: UIScreen.main.bounds.width * 0.69)
            .padding(.trailing, 2)
            
            HStack {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 3)
                        .foregroundColor(Color(hex: "#ECECEC"))
                        .frame(width: 54, height: 54)
                    
                    if let selectedFamilyMember {
                        Image(selectedFamilyMember.familyMemberImage)
                            .resizable()
                            .frame(width: 44, height: 44)
                    }
                }
                
                Spacer()
            }
            .padding(.top, 4)
            .frame(height: 79, alignment: .top)
        }
    }
    
    func selectFamilyMember(ele: FamilyMemberModel) {
        let temp = selectedFamilyMember
        selectedFamilyMember = ele
        withAnimation(.linear) {
            familyMembersList.removeAll{ $0.familyMemberName == ele.familyMemberName }
        }
        if let temp {
            withAnimation(.linear) {
                familyMembersList.append(temp)
            }
        }
    }
    
    @ViewBuilder
    func circleImage(image: String, name: String) -> some View {
        VStack(spacing: 4) {
            Circle()
                .frame(width: 46, height: 46)
                .foregroundStyle(Color(hex: "#D9D9D9"))
                .overlay(
                    Image(image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                )
            
            Text(name)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Color(hex: "#898A8D"))
        }
    }
}

#Preview {
    FamilyCarouselView()
        .padding(.horizontal, 25)
}
