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
    case generateAvatar
    
    var id: String { self.rawValue }
}

struct IngrediFamCanvasView: View {
    
    @State var addFamilyMemberSheetOption: AddFamilyMemberSheetOption? = .allSet
    @State var isExpandedMinimal: Bool = false
    
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
                Button("generateAvatar") {
                    addFamilyMemberSheetOption = .generateAvatar
                }
            }
        }
        CustomSheet(item: $addFamilyMemberSheetOption,
                    cornerRadius: 34,
                    heightsForItem: { sheet in
                        switch sheet {
                        case .addMoreMember: return (min: 437, max: 438)
                        case .allSet: return (min: 270, max: 271)
                        case .meetYourIngrediFam: return (min: 396, max: 397)
                        case .whatsYourName: return (min: 437, max: 438)
                        case .generateAvatar: return (min: 379, max: 642)
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
            case .generateAvatar:
                GenerateAvatar(isExpandedMinimal: $isExpandedMinimal)
            }
        }
//        .sheet(item: $addFamilyMemberSheetOption) { sheet in
//            switch sheet {
//            case .addMoreMember:
//                AddMoreMembers()
//            case .allSet:
//                AllSet()
//            case .meetYourIngrediFam:
//                MeetYourIngrediFam()
//            case .whatsYourName:
//                WhatsYourName()
//            case .generateAvatar:
//                GenerateAvatar(isExpandedMinimal: $isExpandedMinimal)
//                    .presentationDetents([.height(379), .height(642)])
//            }
//        }
        
    }
}

struct GenerateAvatar: View {
    
    @State var toolIcons: [String] = [
        "family-member",
        "gesture",
        "hair-style",
        "skin-tone",
        "accessories",
        "color-theme"
    ]
    
    @State var familyMember: [UserModel] = [
        UserModel(familyMemberName: "Grandfather", familyMemberImage: "image-bg3"),
        UserModel(familyMemberName: "Grandmother", familyMemberImage: "image-bg2"),
        UserModel(familyMemberName: "Daughter", familyMemberImage: "image-bg5"),
        UserModel(familyMemberName: "Brother", familyMemberImage: "image-bg4"),
        UserModel(familyMemberName: "Grandfather", familyMemberImage: "image-bg3"),
        UserModel(familyMemberName: "Grandmother", familyMemberImage: "image-bg2"),
        UserModel(familyMemberName: "Daughter", familyMemberImage: "image-bg5"),
        UserModel(familyMemberName: "Brother", familyMemberImage: "image-bg4"),
        UserModel(familyMemberName: "Grandfather", familyMemberImage: "image-bg3"),
        UserModel(familyMemberName: "Grandmother", familyMemberImage: "image-bg2"),
        UserModel(familyMemberName: "Daughter", familyMemberImage: "image-bg5"),
        UserModel(familyMemberName: "Brother", familyMemberImage: "image-bg4")
    ]
    
    @State var selectedFamilyMember: UserModel = UserModel(familyMemberName: "Son", familyMemberImage: "image-bg1")
    
    @State var selectedTool: String = "family-member"
    @Binding var isExpandedMinimal: Bool
    @Namespace private var animation
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if geometry.size.height >= 500 {
                    VStack {
                        Image(.funGuy)
                        
                        Text("AI Memojis")
                        
                        Text("Create Personalized family Avatar")
                        
                        Text("Generate Avatar")
                        
                        HStack {
                            Image(.familyMember)
                                
                            Text("Family Member")
                        }
                        
                        Text("Tell us how you're related to them so we can create the perfect avatar!")
                    }
                } else {
                    if isExpandedMinimal {
                        VStack {
                            Spacer()
                            selectedMemberRow()
                        }
                        .matchedGeometryEffect(id: "circle", in: animation)
                    } else {
                        VStack(spacing: 40) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Generate Avatar: \(geometry.size.height.description)")
                                        .font(ManropeFont.bold.size(14))
                                        .foregroundStyle(.grayScale150)
                                    
                                    Spacer()
                                    
                                    Text("0/2")
                                        .font(ManropeFont.regular.size(14))
                                        .foregroundStyle(.grayScale100)
                                }
                                .padding(.horizontal, 20)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(toolIcons, id: \.self) { ele in
                                            GenerateAvatarToolPill(icon: ele, title: ele, isSelected: $selectedTool) {
                                                selectedTool = ele
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                
                                Text("Tell us how you’re related to them so we can create the perfect avatar!")
                                    .font(ManropeFont.medium.size(12))
                                    .foregroundStyle(.grayScale120)
                                    .padding(.horizontal, 20)
                                
                                selectedMemberRow()
                                    .matchedGeometryEffect(id: "circle", in: animation)
                            }
                            
                            HStack {
                                GreenOutlinedCapsule(image: "ai-stick", title: "Random")
                                Spacer()
                                GreenCapsule(title: "Generate", icon: "stars-generate")
                            }
                            .padding(.horizontal, 20)
                            
                        }
                        .padding(.top,isExpandedMinimal ? 10 : 32)
                    }
                }
                
            }
            .overlay(alignment: .bottom) {
                if isExpandedMinimal {
                    familyMemberListView()
                }
            }
            .animation(.easeInOut, value: isExpandedMinimal)
        }
    }
    
    @ViewBuilder
    func selectedMemberRow() -> some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(Color(hex: "F9F9F9"))
                    
                    Image(selectedFamilyMember.image)
                        .resizable()
                        .frame(width: 30, height: 30)
                        .shadow(color: Color(hex: "DEDDDD"), radius: 3.5, x: 0, y: 0)
                }
                
                Text(selectedFamilyMember.name)
                    .font(ManropeFont.medium.size(14))
                    .foregroundStyle(.grayScale150)
            }
            
            Spacer()
            
            Image(.arrow)
                .resizable()
                .frame(width: 24, height: 24)
                .rotationEffect(Angle(degrees: 180))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.grayScale10)
                .shadow(color: Color(hex: "ECECEC").opacity(0.4), radius: 5, x: 0, y: 0)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(lineWidth: 0.5)
                        .foregroundStyle(.grayScale40)
                )
            
        )
        .padding(.horizontal, 20)
        .onTapGesture {
            withAnimation(.easeInOut) {
                isExpandedMinimal.toggle()
            }
        }
    }
    
    @ViewBuilder
    func familyMemberListView() -> some View {
        VStack {
            ScrollView {
                VStack {
                    ForEach(familyMember) { member in
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .frame(width: 36, height: 36)
                                    .foregroundStyle(Color(hex: "F9F9F9"))
                                
                                Image(member.image)
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .shadow(color: Color(hex: "DEDDDD"), radius: 3.5, x: 0, y: 0)
                            }
                            
                            Text(member.name)
                                .font(ManropeFont.medium.size(14))
                                .foregroundStyle(.grayScale150)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            selectedFamilyMember = member
                            isExpandedMinimal = false
                        }
                    }
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.35)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.grayScale10)
                .shadow(color: Color(hex: "ECECEC"), radius: 5, x: 0, y: 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 0.5)
                .foregroundStyle(.grayScale40)
        )
        .padding(.bottom, 40)
        .padding(.horizontal, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .offset(y: -30)
    }
}



#Preview {
    GenerateAvatar(isExpandedMinimal: .constant(false))
//    IngrediFamCanvasView()
}
