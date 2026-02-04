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
    private let continuePressed: (String, UIImage?, String?, String?) async throws -> Void

    init(continuePressed: @escaping (String, UIImage?, String?, String?) async throws -> Void = { _, _, _, _ in }) {
        self.continuePressed = continuePressed
    }

    var body: some View {
        VStack {
            
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    HStack {
                        Microcopy.text(Microcopy.Key.Family.Setup.AddMembers.title)
                            .font(NunitoFont.bold.size(22))
                            .foregroundStyle(.grayScale150)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) {
                        // No back button when opened from home screen - allow drag down to dismiss
                        if case .home = coordinator.currentCanvasRoute {
                            // Back button removed - sheet can be dragged down to dismiss
                        } else if !familyStore.pendingOtherMembers.isEmpty {
                            Button {
                                coordinator.navigateInBottomSheet(.addMoreMembersMinimal)
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

                    Microcopy.text(Microcopy.Key.Family.Setup.AddMembers.subtitle)
                        .font(ManropeFont.medium.size(12))
                        .foregroundStyle(.grayScale120)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                
                VStack(alignment: .leading, spacing: 8) {
                    TextField(LocalizedStringKey(Microcopy.Key.Family.Setup.AddMembers.namePlaceholder), text: $name)
                        .padding(16)
                        .background(.grayScale10)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(lineWidth: showError ? 2 : 0.5)
                                .foregroundStyle(showError ? .red : .grayScale60)
                        )
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
                        Microcopy.text(Microcopy.Key.Validation.enterName)
                            .font(ManropeFont.medium.size(12))
                            .foregroundStyle(.red)
                            .padding(.leading, 4)
                    }
                }
                .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 12) {
                    Microcopy.text(Microcopy.Key.Labels.chooseAvatarOptional)
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
                        await handleAddMember(trimmed: trimmed)
                    }
                }
            } label: {
                GreenCapsule(
                    title: Microcopy.string(Microcopy.Key.Family.Setup.AddMembers.ctaAddMember),
                    width: 159,
                    isLoading: isLoading,
                    isDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
            .disabled(isLoading || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dismissKeyboardOnTap()
        .overlay(
            // Only show drag indicator when sheet is draggable (opened from home screen)
            Group {
                if case .home = coordinator.currentCanvasRoute {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.neutral500)
                        .frame(width: 60, height: 4)
                        .padding(.top, 11)
                }
            }
            , alignment: .top
        )
        .onAppear {
            // Check if returning from generate avatar flow
            if memojiStore.previousRouteForGenerateAvatar == .addMoreMembers {
                // Restore the name from memojiStore if coming back from avatar generation
                if let savedName = memojiStore.displayName, !savedName.isEmpty {
                    name = savedName
                }
                // Don't reset - preserve the avatar selection state
            } else {
                // Fresh start - reset all local state when adding a new member
                name = ""
                selectedFamilyMember = nil
                showError = false
                resetMemojiSelectionState()
            }
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
        if let selectedImageName = selectedFamilyMember?.image {
            // Check if it's a local memoji (starts with "memoji_")
            if selectedImageName.hasPrefix("memoji_") {
                // Local memoji selected - use storagePath, no upload needed
                storagePath = selectedImageName
                uploadImage = nil
                // Extract background color if available
                if let color = selectedFamilyMember?.backgroundColor {
                    colorHex = color.toHex()
                }
            } else {
                // Legacy predefined avatar (shouldn't happen after migration, but handle gracefully)
                if let assetImage = UIImage(named: selectedImageName) {
                    uploadImage = assetImage
                    if let color = selectedFamilyMember?.backgroundColor {
                        colorHex = color.toHex()
                    }
                } else {
                    // Fallback
                    storagePath = selectedImageName
                }
            }
        } else if let customImage = memojiStore.image {
            // Custom avatar from memojiStore (user-generated memoji)
            uploadImage = customImage
            colorHex = memojiStore.backgroundColorHex
        }
        
        // Call continue callback with all data
        do {
            try await continuePressed(trimmed, uploadImage, storagePath, colorHex)
            
            // On success, clean up UI state
            name = ""
            showError = false
            selectedFamilyMember = nil
            // Reset memojiStore state so next member starts fresh
            resetMemojiSelectionState()
        } catch {
             print("[AddMoreMembers] Error adding member: \(error)")
             ToastManager.shared.show(message: Microcopy.string(Microcopy.Key.Errors.Family.addMember), type: .error)
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
