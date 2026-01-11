//
//  WhatsYourName.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 28/10/25.
//

import SwiftUI

struct WhatsYourName: View {
    
    @Environment(MemojiStore.self) private var memojiStore
    @Environment(FamilyStore.self) private var familyStore
    @Environment(WebService.self) private var webService
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(ToastManager.self) private var toastManager
    @State var name: String = ""
    @State var showError: Bool = false
    @State var isLoading: Bool = false
    @State var familyMembersList: [UserModel] = [
        UserModel(familyMemberName: "Neha", familyMemberImage: "image-bg5", backgroundColor: Color(hex: "F9C6D0")),
        UserModel(familyMemberName: "Aarnav", familyMemberImage: "image-bg4", backgroundColor: Color(hex: "FFF6B3")),
        UserModel(familyMemberName: "Harsh", familyMemberImage: "image-bg1", backgroundColor: Color(hex: "FFD9B5")),
        UserModel(familyMemberName: "Grandpa", familyMemberImage: "image-bg3", backgroundColor: Color(hex: "BFF0D4")),
        UserModel(familyMemberName: "Grandma", familyMemberImage: "image-bg2", backgroundColor: Color(hex: "A7D8F0"))
    ]
    @State var selectedFamilyMember: UserModel? = nil
    
    var continuePressed: (String) async throws -> Void = { _ in }
    
    init(continuePressed: @escaping (String) async throws -> Void = { _ in }) {
        self.continuePressed = continuePressed
    }
    
    var body: some View {
        VStack {
            
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    HStack {
                        Text("What's your name?")
                            .font(NunitoFont.bold.size(22))
                            .foregroundStyle(.grayScale150)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) {
                        Button {
                            coordinator.navigateInBottomSheet(.letsMeetYourIngrediFam)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

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
                        .autocorrectionDisabled(true)   // ✅ stops autocorrect
                        .onChange(of: name) { oldValue, newValue in
                            if showError && !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                showError = false
                            }
                            
                            // Filter to letters and spaces only
                            let filtered = newValue.filter { $0.isLetter || $0.isWhitespace }
                            var finalized = filtered
                            
                            // Limit to 25 characters
                            if finalized.count > 25 {
                                finalized = String(finalized.prefix(25))
                            }
                            
                            // Limit to max 3 words (max 2 spaces)
                            let components = finalized.components(separatedBy: .whitespaces)
                            if components.count > 3 {
                                finalized = components.prefix(3).joined(separator: " ")
                            }
                            
                            if finalized != newValue {
                                name = finalized
                            }
                        }
                    
                    if showError {
                        Text("Enter a name.")
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
                            Button {
                                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed.isEmpty {
                                    // Show error if textfield is empty
                                    showError = true
                                } else {
                                    // Proceed to generate avatar
                                    memojiStore.displayName = trimmed
                                    coordinator.navigateInBottomSheet(.generateAvatar)
                                }
                            } label: {
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
                            }
                            .buttonStyle(.plain)
                            
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
                    Task {
                        await handleContinue(trimmed: trimmed)
                    }
                }
            } label: {
                GreenCapsule(
                    title: "Continue",
                    width: 159,
                    isLoading: isLoading,
                    isDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                .frame(width: 159)
            }
            .disabled(isLoading || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        .onAppear {
            // Restore the name from memojiStore if available
            if let displayName = memojiStore.displayName, !displayName.isEmpty {
                name = displayName
            }
        }
    }
    
    @MainActor
    private func handleContinue(trimmed: String) async {
        print("[WhatsYourName] Continue tapped with name=\(trimmed)")
        isLoading = true
        defer { isLoading = false }
        
        familyStore.setPendingSelfMember(name: trimmed)
        
        // Handle avatar assignment - upload in background without blocking UI
        // Priority:
        // 1. Selected predefined avatar (upload to productimages)
        // 2. Custom memoji (use memoji-images storage path, no re-upload)
        if let selectedImageName = selectedFamilyMember?.image,
           let assetImage = UIImage(named: selectedImageName) {
            // Predefined avatar selected - upload it
            await familyStore.setPendingSelfMemberAvatar(image: assetImage, webService: webService)
        } else if let storagePath = memojiStore.imageStoragePath, !storagePath.isEmpty {
            // Custom avatar from memojiStore - use memoji storage path directly
            await familyStore.setPendingSelfMemberAvatarFromMemoji(
                storagePath: storagePath,
                backgroundColorHex: memojiStore.backgroundColorHex
            )
        } else if let selectedImageName = selectedFamilyMember?.image {
            // Fallback to old method if image can't be loaded
            familyStore.setPendingSelfMemberAvatar(imageName: selectedImageName)
        }
        
        do {
            try await continuePressed(trimmed)
        } catch {
            print("[WhatsYourName] Error creating family: \(error)")
            toastManager.show(message: "Failed to create family: \(error.localizedDescription)", type: .error)
        }
    }
}
