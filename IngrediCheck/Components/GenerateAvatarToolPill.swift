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
    var onTap: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                // Show selected item icon if available, otherwise show default category icon
                Image(selectedItemIcon ?? icon)
                    .resizable()
                    .frame(width:(isSelected == icon) ? 20 : 24, height: (isSelected == icon) ? 20 : 24)
                
                    Circle()
                        .stroke(lineWidth: 0.5)
                        .foregroundStyle(.grayScale60)
                        .frame(width: (isSelected == icon) ? 0 : 36, height: (isSelected == icon) ? 0 : 36)
                        .opacity((isSelected == icon) ? 0 : 1)
            }
            
            if (isSelected == icon) {
                Text(title)
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(Color(hex: "#404040"))
                    .offset(x: (isSelected == icon) ? 0 : -30)
                    .opacity((isSelected == icon) ? 1 : 0)
            }
        }
        .padding(.vertical, (isSelected == icon) ? 8 : 0)
        .padding(.leading, (isSelected == icon) ? 12 : 0)
        .padding(.trailing, (isSelected == icon) ? 16 : 0)
        .background((isSelected == icon) ? Color(hex: "#DFDFDF") : .clear, in: RoundedRectangle(cornerRadius: 36))
        .onTapGesture {
            withAnimation(.smooth) {
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
