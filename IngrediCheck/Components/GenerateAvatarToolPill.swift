//
//  GenerateAvatarToolPill.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 06/10/25.
//

import SwiftUI

struct GenerateAvatarToolPill: View {
    var icon: String = "family-member"
    var title: String = "Family Member"
    @Binding var isSelected: String
    var selectedItemIcon: String? = nil // Icon of the selected item within this tool category
    var primaryIcon: String? = nil // Primary icon name for selected state (e.g., "family-member-Primary")
    var onTap: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 9) {
            // When selected, use primaryIcon if provided, otherwise use default icon
            // When not selected, use default icon
            let iconToDisplay = (isSelected == icon && primaryIcon != nil) ? primaryIcon! : icon
            Image(iconToDisplay)
                .renderingMode(.original)  // Add this line to prevent template rendering
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .clipped()
            
           
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.4)) {
                onTap?()
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        HStack {
            GenerateAvatarToolPill(isSelected: .constant("family-member"))
            GenerateAvatarToolPill(isSelected: .constant(""))
            GenerateAvatarToolPill(isSelected: .constant(""))
        }
        
    }
}
