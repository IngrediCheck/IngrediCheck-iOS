//
//  IngrediFamCanvasView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 16/10/25.
//

import SwiftUI

enum AddFamilyMemberSheetOption: String, Identifiable {
    case meetYourIngrediFam
    case whatsYourName
    case addMoreMember
    case allSet
    
    var id: String { self.rawValue }
}

struct IngrediFamCanvasView: View {
    
    @State var addFamilyMemberSheetOption: AddFamilyMemberSheetOption? = .whatsYourName
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.grayScale10)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(lineWidth: 0.5)
                        .foregroundStyle(.grayScale60)
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
            
            VStack(spacing: 20) {
                Button("addMoreMember") {
                    addFamilyMemberSheetOption = .addMoreMember
                }
                Button("allSet") {
                    addFamilyMemberSheetOption = .allSet
                }
                Button("meetYourIngrediFam") {
                    addFamilyMemberSheetOption = .meetYourIngrediFam
                }
                Button("whatsYourName") {
                    addFamilyMemberSheetOption = .whatsYourName
                }
            }
        }
        CustomSheet(item: $addFamilyMemberSheetOption,
                    cornerRadius: 24,
                    heightForItem: { sheet in
                        switch sheet {
                        case .addMoreMember: return 437
                        case .allSet: return 270
                        case .meetYourIngrediFam: return 396
                        case .whatsYourName: return 437
                        }
                    }) { sheet in
            switch sheet {
            case .addMoreMember:
                AddMoreMembers()
            case .allSet:
                AllSet()
            case .meetYourIngrediFam:
                MeetYourIngrediFam()
            case .whatsYourName:
                WhatsYourName()
            }
        }

    }
}


struct MeetYourIngrediFam: View {
    var body: some View {
        VStack(spacing: 20) {
            Image("IngrediFamGroup")
                .resizable()
                .frame(width: 295, height: 146)
            
            VStack(spacing: 16) {
                Text("Let's meet your IngrediFam!")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                
                Text("Add everyone’s name and a fun avatar so we can tailor tips and scans just for them.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
                
                
                GreenCapsule(title: "Add Members")
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}

struct WhatsYourName: View {
    @State var name: String = ""
    @State var familyMembersList: [UserModel] = [
        UserModel(familyMemberName: "Neha", familyMemberImage: "image-bg5", backgroundColor: Color(hex: "F9C6D0")),
        UserModel(familyMemberName: "Aarnav", familyMemberImage: "image-bg4", backgroundColor: Color(hex: "FFF6B3")),
        UserModel(familyMemberName: "Harsh", familyMemberImage: "image-bg1", backgroundColor: Color(hex: "FFD9B5")),
        UserModel(familyMemberName: "Grandpa", familyMemberImage: "image-bg3", backgroundColor: Color(hex: "BFF0D4")),
        UserModel(familyMemberName: "Grandma", familyMemberImage: "image-bg2", backgroundColor: Color(hex: "A7D8F0"))
    ]
    @State var selectedFamilyMember: UserModel? = nil
    var body: some View {
        VStack {
            
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("What's your name?")
                        .font(NunitoFont.bold.size(22))
                        .foregroundStyle(.grayScale150)
                    
                    Text("This helps us personalize your experience and scan tips—just for you!")
                        .font(ManropeFont.medium.size(12))
                        .foregroundStyle(.grayScale120)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                
                TextField("Enter your Name", text: $name)
                    .padding(16)
                    .background(.grayScale10)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(lineWidth: 0.5)
                            .foregroundStyle(.grayScale60)
                    )
                    .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
                    .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Avatar (Optional)")
                        .font(ManropeFont.bold.size(14))
                        .foregroundStyle(.grayScale150)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(familyMembersList, id: \.id) { ele in
                                ZStack(alignment: .topTrailing) {
                                    circleImage(image: ele.image, name: ele.name, color: ele.backgroundColor ?? .clear)
                                    
                                    if selectedFamilyMember?.id == ele.id {
                                        Circle()
                                            .fill(Color(hex: "2C9C3D"))
                                            .frame(width: 16, height: 16)
                                            .padding(.top, 1)
                                            .overlay(
                                                Circle()
                                                    .stroke(lineWidth: 1)
                                                    .foregroundStyle(.white)
                                                    .padding(.top, 1)
                                                    .overlay(
                                                        Image("white-rounded-checkmark")
                                                    )
                                            )
                                    }
                                }
                                .onTapGesture {
                                    selectedFamilyMember = ele
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 20)
            }
            .padding(.bottom, 40)
            
            HStack(spacing: 16) {
                GreenOutlinedCapsule(image: "stars-generate", title: "Generate")
                GreenCapsule(title: "Add Member")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}

struct AddMoreMembers: View {
    @State var name: String = ""
    @State var familyMembersList: [UserModel] = [
        UserModel(familyMemberName: "Neha", familyMemberImage: "image-bg5", backgroundColor: Color(hex: "F9C6D0")),
        UserModel(familyMemberName: "Aarnav", familyMemberImage: "image-bg4", backgroundColor: Color(hex: "FFF6B3")),
        UserModel(familyMemberName: "Harsh", familyMemberImage: "image-bg1", backgroundColor: Color(hex: "FFD9B5")),
        UserModel(familyMemberName: "Grandpa", familyMemberImage: "image-bg3", backgroundColor: Color(hex: "BFF0D4")),
        UserModel(familyMemberName: "Grandma", familyMemberImage: "image-bg2", backgroundColor: Color(hex: "A7D8F0"))
    ]
    @State var selectedFamilyMember: UserModel? = nil
    var body: some View {
        VStack {
            
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Add more members?")
                        .font(NunitoFont.bold.size(22))
                        .foregroundStyle(.grayScale150)
                    
                    Text("Start by adding their name and a fun avatar—it’ll help us personalize food tips just for them.")
                        .font(ManropeFont.medium.size(12))
                        .foregroundStyle(.grayScale120)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                
                TextField("Enter your Name", text: $name)
                    .padding(16)
                    .background(.grayScale10)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(lineWidth: 0.5)
                            .foregroundStyle(.grayScale60)
                    )
                    .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
                    .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Avatar (Optional)")
                        .font(ManropeFont.bold.size(14))
                        .foregroundStyle(.grayScale150)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(familyMembersList, id: \.id) { ele in
                                ZStack(alignment: .topTrailing) {
                                    circleImage(image: ele.image, name: ele.name, color: ele.backgroundColor ?? .clear)
                                    
                                    if selectedFamilyMember?.id == ele.id {
                                        Circle()
                                            .fill(Color(hex: "2C9C3D"))
                                            .frame(width: 16, height: 16)
                                            .padding(.top, 1)
                                            .overlay(
                                                Circle()
                                                    .stroke(lineWidth: 1)
                                                    .foregroundStyle(.white)
                                                    .padding(.top, 1)
                                                    .overlay(
                                                        Image("white-rounded-checkmark")
                                                    )
                                            )
                                    }
                                }
                                .onTapGesture {
                                    selectedFamilyMember = ele
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 20)
            }
            .padding(.bottom, 40)
            
            HStack(spacing: 16) {
                GreenOutlinedCapsule(image: "stars-generate", title: "Generate")
                GreenCapsule(title: "Add Member")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}


struct AllSet: View {
    var body: some View {
        VStack {
            VStack(spacing: 12) {
                Text("Add more members?")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                
                Text("Start by adding their name and a fun avatar—it’ll help us personalize food tips just for them.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)
            
            HStack(spacing: 16) {
                Button {
                    
                } label: {
                    Text("All Set!")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .frame(width: 160, height: 52)
                        .background(
                            .grayScale40, in: RoundedRectangle(cornerRadius: 28)
                        )
                }

                
                GreenCapsule(title: "Add Member", width: 160, height: 52)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}

#Preview {
    IngrediFamCanvasView()
}
