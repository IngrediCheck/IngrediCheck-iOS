//
//  GenerateAvatarToolPill.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 06/10/25.
//

import SwiftUI

struct GenerateAvatarToolPill: View {
    @State var isSelected: Bool = true
    @State var onTap: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Image("family-member")
                    .resizable()
                    .frame(width: 24, height: 24)
                
                    Circle()
                        .stroke(lineWidth: 0.5)
                        .foregroundStyle(Color(hex: "#989393"))
                        .frame(width: 36, height: 36)
                        .opacity(isSelected ? 0 : 1)
                
            }
            
            if isSelected {
                Text("Family Member")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color(hex: "#404040"))
                    .offset(x: isSelected ? 0 : -30)
//                    .opacity(isSelected ? 1 : 0)
            }
        }
        .padding(.vertical, isSelected ? 6 : nil)
        .padding(.leading, isSelected ? 8 : nil)
        .padding(.trailing, isSelected ? 12 : nil)
        .background(isSelected ? Color(hex: "#DFDFDF") : .clear, in: .capsule)
        .onTapGesture {
            withAnimation(.smooth) {
                isSelected.toggle()
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        GenerateAvatarToolPill()
    }
}
