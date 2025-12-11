//
//  WhatsYourName.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 28/10/25.
//

import SwiftUI

struct WhatsYourName: View {
    
    @Environment(FamilyStore.self) private var familyStore
    @State var name: String = ""
    @State var showError: Bool = false
    @State var familyMembersList: [UserModel] = [
        UserModel(familyMemberName: "Neha", familyMemberImage: "image-bg5", backgroundColor: Color(hex: "F9C6D0")),
        UserModel(familyMemberName: "Aarnav", familyMemberImage: "image-bg4", backgroundColor: Color(hex: "FFF6B3")),
        UserModel(familyMemberName: "Harsh", familyMemberImage: "image-bg1", backgroundColor: Color(hex: "FFD9B5")),
        UserModel(familyMemberName: "Grandpa", familyMemberImage: "image-bg3", backgroundColor: Color(hex: "BFF0D4")),
        UserModel(familyMemberName: "Grandma", familyMemberImage: "image-bg2", backgroundColor: Color(hex: "A7D8F0"))
    ]
    @State var selectedFamilyMember: UserModel? = nil
    
    @State var continuePressed: () -> Void = { }
    
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
                
                
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Enter your Name", text: $name)
                        .padding(16)
                        .background(.grayScale10)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(lineWidth: showError ? 2 : 0.5)
                                .foregroundStyle(showError ? .red : .grayScale60)
                        )
                        .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
                        .onChange(of: name) { _, newValue in
                            if showError && !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                showError = false
                            }
                        }
                    
                    if showError {
                        Text("Please enter your name")
                            .font(ManropeFont.medium.size(12))
                            .foregroundStyle(.red)
                            .padding(.leading, 4)
                    }
                }
                .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Avatar (Optional)")
                        .font(ManropeFont.bold.size(14))
                        .foregroundStyle(.grayScale150)
                        .padding(.leading, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .stroke(lineWidth: 2)
                                    .foregroundStyle(.grayScale60)
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: "plus")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(.grayScale60)
                            }
                            
                            ForEach(familyMembersList, id: \.id) { ele in
                                ZStack(alignment: .topTrailing) {
                                    Image(ele.image)
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                    
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
                        .padding(.horizontal, 20)
                    }
                }
                
            }
            .padding(.bottom, 40)
            
            Button {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    showError = true
                } else {
                    print("[WhatsYourName] Continue tapped with name=\(trimmed)")
                    familyStore.setPendingSelfMember(name: trimmed)
                    continuePressed()
                }
            } label: {
                GreenCapsule(title: "Continue")
                    .frame(width: 159)
            }
            .padding(.horizontal, 20)
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
