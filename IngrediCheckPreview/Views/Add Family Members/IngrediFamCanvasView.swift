//
//  IngrediFamCanvasView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 16/10/25.
//

import SwiftUI

struct GenerateAvatarTools: Identifiable {
    let id = UUID().uuidString
    var title: String
    var icon: String
    var tools: [ChipsModel]
}

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
    
    @State var tools: [GenerateAvatarTools] = [
        GenerateAvatarTools(
            title: "Gesture",
            icon: "gesture",
            tools: [
                ChipsModel(name: "Wave", icon: "wave"),
                ChipsModel(name: "Thumbs Up", icon: "thumbs-up"),
                ChipsModel(name: "Heart Hands", icon: "heart-hands"),
                ChipsModel(name: "Phone in Hand", icon: "phone-in-hand"),
                ChipsModel(name: "Peace", icon: "peace"),
                ChipsModel(name: "Pointing", icon: "pointing")
            ]
        ),
        GenerateAvatarTools(
            title: "Hair Style",
            icon: "hair-style",
            tools: [
                ChipsModel(name: "Short hair", icon: "short-hair"),
                ChipsModel(name: "Long hair", icon: "long-hair"),
                ChipsModel(name: "straight hair", icon: "straight-hair"),
                ChipsModel(name: "Ponytail", icon: "ponytail"),
                ChipsModel(name: "Curly hair", icon: "curly-hair"),
                ChipsModel(name: "Bun", icon: "bun"),
                ChipsModel(name: "Bald", icon: "bald")
            ]
        ),
        GenerateAvatarTools(
            title: "Skin Tone",
            icon: "skin-tone",
            tools: [
                ChipsModel(name: "Light", icon: "light"),
                ChipsModel(name: "Medium", icon: "medium"),
                ChipsModel(name: "Tan", icon: "tan"),
                ChipsModel(name: "Deep", icon: "deep"),
                ChipsModel(name: "Freckled", icon: "freckled")
            ]
        ),
        GenerateAvatarTools(
            title: "Accessories",
            icon: "accessories",
            tools: [
                ChipsModel(name: "None", icon: "none"),
                ChipsModel(name: "Glasses", icon: "glasses"),
                ChipsModel(name: "Hat", icon: "hat"),
                ChipsModel(name: "Earrings", icon: "earrings"),
                ChipsModel(name: "Sunglasses", icon: "sunglasses"),
                ChipsModel(name: "Cap", icon: "cap")
            ]
        ),
        GenerateAvatarTools(
            title: "Color Theme",
            icon: "color-theme",
            tools: [
                ChipsModel(name: "Pastel Blue", icon: "pastel-blue"),
                ChipsModel(name: "Warm Pink", icon: "warm-pink"),
                ChipsModel(name: "Soft Green", icon: "soft-green"),
                ChipsModel(name: "Lavender", icon: "lavender"),
                ChipsModel(name: "Cream", icon: "cream"),
                ChipsModel(name: "Mint", icon: "mint"),
                ChipsModel(name: "Transparent", icon: "transparent")
            ]
        )
    ]
    
    @State var isExpandedMaximal: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if geometry.size.height >= 500 {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            
                            if isExpandedMaximal == false {
                                VStack(spacing: 4) {
                                    Image(.funGuy)
                                    
                                    Text("AI Memojis")
                                        .font(ManropeFont.bold.size(16))
                                        .foregroundStyle(.grayScale150)
                                    
                                    Text("Create Personalized family Avatar")
                                        .font(ManropeFont.medium.size(12))
                                        .foregroundStyle(.grayScale150)
                                }
                                
                                Text("Generate Avatar")
                                    .font(ManropeFont.bold.size(14))
                                    .foregroundStyle(.grayScale150)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            VStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(.familyMember)
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundStyle(.grayScale150)
                                            .frame(width: 22, height: 24)
                                        
                                        Text("Family Member")
                                            .font(ManropeFont.semiBold.size(16))
                                            .foregroundStyle(.grayScale150)
                                    }
                                    
                                    Text("Tell us how you're related to them so we can create the perfect avatar!")
                                        .font(ManropeFont.medium.size(12))
                                        .foregroundStyle(.grayScale120)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                CollapseFamilyList(collapsed: $isExpandedMaximal, familyNames: familyMember)
                            }
                            
                            .padding(.bottom, 30)
                            
                            
                            if isExpandedMaximal == false {
                                ForEach(tools) { tool in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 8) {
                                            Image(tool.icon)
                                                .resizable()
                                                .renderingMode(.template)
                                                .foregroundStyle(.grayScale150)
                                                .frame(width: 24, height: 24)
                                            
                                            Text(tool.title)
                                                .font(ManropeFont.semiBold.size(16))
                                                .foregroundStyle(.grayScale150)
                                        }
                                        
                                        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                                            ForEach(tool.tools) { innerTool in
                                                
                                                Button {
                                                    
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Image(innerTool.icon ?? "")
                                                            .resizable()
                                                            .frame(width: 24, height: 24)
                                                        
                                                        Text(innerTool.name)
                                                            .font(ManropeFont.medium.size(14))
                                                            .foregroundStyle(.grayScale150)
                                                    }
                                                    .padding(.vertical, 8)
                                                    .padding(.trailing, 16)
                                                    .padding(.leading, 12)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 40)
                                                            .stroke(lineWidth: 1)
                                                            .foregroundStyle(.grayScale60)
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
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
//    GenerateAvatar(isExpandedMinimal: .constant(false))
    IngrediFamCanvasView()
}
