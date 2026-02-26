//
//  AddFoodNotesPromptCard.swift
//  IngrediCheck
//
//  Created for prompting users to add Food Notes from product context.
//

import SwiftUI

struct AddFoodNotesPromptCard: View {
    
    /// Called when the user taps the "Add food notes" button.
    var onAddFoodNotes: (() -> Void)?
    
    var body: some View {
        // Text + button column
        VStack(alignment: .leading, spacing: 18) {
            Text("Want to find out if this Product matches your dietary preferences? Tap below to add your Food Notes.")
                .font(ManropeFont.regular.size(14))
                .foregroundStyle(.grayScale150)
                .fixedSize(horizontal: false, vertical: true)
            
            Button {
                onAddFoodNotes?()
            } label: {
                GreenCapsule(
                    title: "Add food notes",
                    icon: "plus",
                    iconWidth: 18,
                    iconHeight: 18,
                    width: 183,
                    height: 52,
                    takeFullWidth: false,
                    isLoading: false,
                    isDisabled: false,
                    labelFont: NunitoFont.semiBold.size(16),
                    spacing: 4
                )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.grayScale10)
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(lineWidth: 0.3)
                .foregroundStyle(Color(hex: "#D3D3D3"))
        )
        .overlay(
            Image("Group 1171276642")
            , alignment: .bottomTrailing
        )
    }
}

#Preview {
    AddFoodNotesPromptCard()
        .padding(.horizontal, 20)
}

