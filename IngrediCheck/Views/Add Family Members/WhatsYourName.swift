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
    @State var name: String = ""
    @State var showError: Bool = false
    @State var isLoading: Bool = false
    @State var familyMembersList: [UserModel] = [
        UserModel(familyMemberName: "Memoji 1", familyMemberImage: "memoji_1", backgroundColor: Color(hex: "FFB3BA")),
        UserModel(familyMemberName: "Memoji 2", familyMemberImage: "memoji_2", backgroundColor: Color(hex: "FFDFBA")),
        UserModel(familyMemberName: "Memoji 3", familyMemberImage: "memoji_3", backgroundColor: Color(hex: "FFFFBA")),
        UserModel(familyMemberName: "Memoji 4", familyMemberImage: "memoji_4", backgroundColor: Color(hex: "BAFFC9")),
        UserModel(familyMemberName: "Memoji 5", familyMemberImage: "memoji_5", backgroundColor: Color(hex: "BAE1FF")),
        UserModel(familyMemberName: "Memoji 6", familyMemberImage: "memoji_6", backgroundColor: Color(hex: "E0BBE4")),
        UserModel(familyMemberName: "Memoji 7", familyMemberImage: "memoji_7", backgroundColor: Color(hex: "FFCCCB")),
        UserModel(familyMemberName: "Memoji 8", familyMemberImage: "memoji_8", backgroundColor: Color(hex: "B4E4FF")),
        UserModel(familyMemberName: "Memoji 9", familyMemberImage: "memoji_9", backgroundColor: Color(hex: "C7CEEA")),
        UserModel(familyMemberName: "Memoji 10", familyMemberImage: "memoji_10", backgroundColor: Color(hex: "F0E6FF")),
        UserModel(familyMemberName: "Memoji 11", familyMemberImage: "memoji_11", backgroundColor: Color(hex: "FFE5B4")),
        UserModel(familyMemberName: "Memoji 12", familyMemberImage: "memoji_12", backgroundColor: Color(hex: "E8F5E9")),
        UserModel(familyMemberName: "Memoji 13", familyMemberImage: "memoji_13", backgroundColor: Color(hex: "FFF9C4")),
        UserModel(familyMemberName: "Memoji 14", familyMemberImage: "memoji_14", backgroundColor: Color(hex: "F8BBD0"))
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
                    
                    HStack(spacing: 16) {
                        // Fixed plus button (does not scroll)
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
                        
                        // Vertical divider
                        Rectangle()
                            .fill(.grayScale60)
                            .frame(width: 1, height: 48)
                        
                        // Scrollable memojis list
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
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
                        }
                    }
                    .padding(.horizontal, 20)
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
//        .overlay(
//            RoundedRectangle(cornerRadius: 4)
//                .fill(.neutral500)
//                .frame(width: 60, height: 4)
//                .padding(.top, 11)
//            , alignment: .top
//        )
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
        // 1. Selected local memoji (use storagePath, no upload)
        // 2. Custom memoji (use memoji-images storage path, no re-upload)
        if let selectedImageName = selectedFamilyMember?.image {
            // Check if it's a local memoji (starts with "memoji_")
            if selectedImageName.hasPrefix("memoji_") {
                // Local memoji selected - use storagePath, no upload needed
                if let color = selectedFamilyMember?.backgroundColor {
                    let colorHex = color.toHex()
                    await familyStore.setPendingSelfMemberAvatarFromMemoji(
                        storagePath: selectedImageName,
                        backgroundColorHex: colorHex
                    )
                } else {
                    // Fallback if color extraction fails
                    await familyStore.setPendingSelfMemberAvatarFromMemoji(
                        storagePath: selectedImageName,
                        backgroundColorHex: nil
                    )
                }
            } else {
                // Legacy predefined avatar (shouldn't happen after migration, but handle gracefully)
                if let assetImage = UIImage(named: selectedImageName) {
                    await familyStore.setPendingSelfMemberAvatar(image: assetImage, webService: webService)
                } else {
                    familyStore.setPendingSelfMemberAvatar(imageName: selectedImageName)
                }
            }
        } else if let storagePath = memojiStore.imageStoragePath, !storagePath.isEmpty {
            // Custom avatar from memojiStore - use memoji storage path directly
            await familyStore.setPendingSelfMemberAvatarFromMemoji(
                storagePath: storagePath,
                backgroundColorHex: memojiStore.backgroundColorHex
            )
        }
        
        do {
            try await continuePressed(trimmed)
        } catch {
            print("[WhatsYourName] Error creating family: \(error)")
            ToastManager.shared.show(message: "Failed to create family: \(error.localizedDescription)", type: .error)
        }
    }
}
