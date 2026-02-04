//
//  FineTuneYourExperience.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar on 02/12/25.
//

import SwiftUI

struct FineTuneExperience: View {
    @Environment(FamilyStore.self) private var familyStore
    var allSetPressed: () -> Void
    var addPreferencesPressed: () -> Void
    
    @State private var isWaitingForUploads = false
    
    init(
        allSetPressed: @escaping () -> Void = {},
        addPreferencesPressed: @escaping () -> Void = {}
    ) {
        self.allSetPressed = allSetPressed
        self.addPreferencesPressed = addPreferencesPressed
    }
    
    var body: some View {
        VStack {
            VStack(spacing: 12) {
                Text("Want to fine-tune your experience?")
                    .font(NunitoFont.bold.size(20))
                    .foregroundStyle(.grayScale150)
                
                Text("Add extra preferences to tailor your experience. Jump in or skip!")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)
            
            HStack(spacing: 16) {
                SecondaryButton(
                    title: "All Set!",
                    width: 160,
                    takeFullWidth: false,
                    isLoading: isWaitingForUploads || familyStore.pendingUploadCount > 0,
                    isDisabled: isWaitingForUploads || familyStore.pendingUploadCount > 0,
                    action: {
                        Task {
                            await handleAllSet()
                        }
                    }
                )

                
                Button {
                    Task {
                        await handleAddPreferences()
                    }
                } label: {
                    if isWaitingForUploads || familyStore.pendingUploadCount > 0 {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 160, height: 52)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "4CAF50"), Color(hex: "8BC34A")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 28)
                            )
                    } else {
                        GreenCapsule(title: "Add Preferences", width: 160, height: 52)
                    }
                }
                .disabled(isWaitingForUploads || familyStore.pendingUploadCount > 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
//        .overlay(
//            RoundedRectangle(cornerRadius: 4)
//                .fill(.neutral500)
//                .frame(width: 60, height: 4)
//                .padding(.top, 11)
//            , alignment: .top
//        )
    }
    
    @MainActor
    private func handleAllSet() async {
        guard !isWaitingForUploads else { return }
        isWaitingForUploads = true
        
        // Wait for all pending uploads to complete
        await familyStore.waitForPendingUploads()
        
        isWaitingForUploads = false
        allSetPressed()
    }
    
    @MainActor
    private func handleAddPreferences() async {
        guard !isWaitingForUploads else { return }
        isWaitingForUploads = true
        
        // Wait for all pending uploads to complete
        await familyStore.waitForPendingUploads()
        
        isWaitingForUploads = false
        addPreferencesPressed()
    }
}

#Preview {
    FineTuneExperience()
}
