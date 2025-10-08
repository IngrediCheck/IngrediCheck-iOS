//
//  ProfileCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/10/25.
//

import SwiftUI

struct ProfileCard: View {
    var body: some View {
        ZStack {
            
            Circle()
                .frame(width: 66, height: 66)
                .foregroundStyle(.grayScale30)
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
                .overlay(
                    Circle()
                        .stroke(lineWidth: 0.5)
                        .foregroundStyle(.grayScale80)
                )
            
            Circle()
                .foregroundColor(.grayScale10)
                .frame(width: 47, height: 47)
                .shadow(color: Color(hex: "FBFBFB"), radius: 9, x: 0, y: 0)
                .overlay(
                    Image("profile-ritika")
                        .resizable()
                        .frame(width: 38, height: 38)
                )
                .clipShape(.circle)
            
            Text("60%")
                .font(NunitoFont.regular.size(12))
                .frame(height: 9.86)
                .foregroundStyle(.grayScale10)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        
                        RoundedRectangle(cornerRadius: 62)
                            .foregroundStyle(.primary800)
                        
                        RoundedRectangle(cornerRadius: 62)
                            .stroke(Color(hex: "#DAFF67").opacity(0.72), lineWidth: 7)
                            .blur(radius: 2.5)
                            .offset(x: 1, y: 1.1)
                            .mask(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(hex: "#DAFF67").opacity(0.72),
                                            Color(hex: "#DAFF67").opacity(0.68),
                                            Color(hex: "#DAFF67").opacity(0.50),
                                            Color(hex: "#DAFF67").opacity(0.12),
                                                .clear]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                            )
                    }
                )
                .padding(.top, 60)
        }
//        .scaleEffect(2)
    }
}

#Preview {
    ProfileCard()
}
