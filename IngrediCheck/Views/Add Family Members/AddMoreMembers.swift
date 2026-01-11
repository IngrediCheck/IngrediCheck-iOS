//
//  AddMoreMembers.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 28/10/25.
//

import SwiftUI

struct AddMoreMembers: View {
    @Environment(FamilyStore.self) private var familyStore
    @Environment(WebService.self) private var webService
    @Environment(MemojiStore.self) private var memojiStore
    @Environment(ToastManager.self) private var toastManager
    @Environment(AppNavigationCoordinator.self) private var coordinator
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
    @State var continuePressed: (String, UIImage?, String?, String?) async throws -> Void = { _, _, _, _ in }
    
    var body: some View {
        VStack {
            
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Add more members?")
                            .font(NunitoFont.bold.size(22))
                            .foregroundStyle(.grayScale150)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) {
                        if case .home = coordinator.currentCanvasRoute {
                            Button {
                                coordinator.navigateInBottomSheet(.homeDefault)
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Start by adding their name and a fun avatar—it’ll help us personalize food tips just for them.")
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
                                    // Set display name before navigating
                                    memojiStore.displayName = trimmed
                                    // Ensure GenerateAvatar back button returns to AddMoreMembers, not onboarding
                                    memojiStore.previousRouteForGenerateAvatar = .addMoreMembers
                                    // Proceed to generate avatar
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
                        await handleAddMember(trimmed: trimmed)
                    }
                }
            } label: {
                GreenCapsule(
                    title: "Add Member",
                    width: 159,
                    isLoading: isLoading,
                    isDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
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
            // Reset all selection state when adding a new member
            resetMemojiSelectionState()
        }
    }
    
    // Reset all memoji selection state to start fresh for new member
    private func resetMemojiSelectionState() {
        // Set to empty string so restoreState() treats it as fresh start
        memojiStore.selectedFamilyMemberName = ""
        memojiStore.selectedFamilyMemberImage = ""
        memojiStore.selectedTool = "family-member"
        memojiStore.currentToolIndex = 0
        memojiStore.selectedGestureIcon = nil
        memojiStore.selectedHairStyleIcon = nil
        memojiStore.selectedSkinToneIcon = nil
        memojiStore.selectedAccessoriesIcon = nil
        memojiStore.selectedColorThemeIcon = nil
        // Clear displayName to prevent previous member's name from persisting
        memojiStore.displayName = nil
        // Clear previous route so back button works correctly for new flow
        memojiStore.previousRouteForGenerateAvatar = nil
    }
    
    @MainActor
    private func handleAddMember(trimmed: String) async {
        print("[AddMoreMembers] Continue tapped with name=\(trimmed)")
        isLoading = true
        defer { isLoading = false }
        
        var uploadImage: UIImage? = nil
        var storagePath: String? = nil
        var colorHex: String? = nil
        
        // Handle avatar selection
        if let selectedImageName = selectedFamilyMember?.image,
           let assetImage = UIImage(named: selectedImageName) {
            // Predefined avatar selected
            uploadImage = assetImage
            // Predefined models have background color
            // Using a simple extraction if available, otherwise defaulting to valid random color on backend/store
            // We can try to use `description` or similar but Color doesn't expose hex easily.
            // However, we can use the `toHex()` if available or just nil.
            if let color = selectedFamilyMember?.backgroundColor {
                colorHex = color.toHex() 
            }
        } else if let customImage = memojiStore.image {
            // Custom avatar from memojiStore
            uploadImage = customImage
            colorHex = memojiStore.backgroundColorHex
            
        } else if let selectedImageName = selectedFamilyMember?.image {
            // Fallback
            storagePath = selectedImageName // Use as static name
        }
        
        // Call continue callback with all data
        do {
            try await continuePressed(trimmed, uploadImage, storagePath, colorHex)
            
            // On success, clean up UI state
            name = ""
            showError = false
        } catch {
             print("[AddMoreMembers] Error adding member: \(error)")
             toastManager.show(message: "Failed to add member: \(error.localizedDescription)", type: .error)
        }
    }
}

extension Color {
    func toHex() -> String? {
        // Platform agnostic way to get hex from SwiftUI Color
        // Convert to UIColor/NSColor first
        let uiColor = UIColor(self)
        guard let components = uiColor.cgColor.components, components.count >= 3 else {
            return nil
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != 1.0 {
            return String(format: "#%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}
