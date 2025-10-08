//
//  CreateYourAvatarCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/10/25.
//

import SwiftUI

struct CreateYourAvatarCard: View {
    var body: some View {
        ZStack {
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create Your Avatar")
                            .font(ManropeFont.medium.size(18))
                            .foregroundStyle(.grayScale150)
                        
                        Text("Create a fun digital version of yourself.")
                            .font(ManropeFont.light.size(12))
                            .foregroundStyle(.grayScale100)
                            .lineLimit(2)
                    }
                    
                    HStack(alignment: .center, spacing: 4) {
                        Text("Explore")
                            .font(ManropeFont.regular.size(12))
                            .foregroundStyle(.grayScale150)
                        
                        Image("right-arrow")
                            .resizable()
                            .frame(width: 12, height: 12)
                    }
                    .foregroundStyle(.grayScale150)
                }
                
                HStack(spacing: -11) {
                    avatarCircle(imageName: "bald-lady", size: 47.5, color: Color(hex: "#F9C6D0"))
                        .zIndex(2)
                    
                    avatarCircle(imageName: "curly-lady", size: 66.5, color: Color(hex: "#DCC7F6"))
                        .overlay(
                            ZStack {
                                
                                Circle()
                                    .foregroundStyle(Color(hex: "#FEFEFE").opacity(0.94))
                                    .frame(width: 25, height: 25)
                                    .shadow(color: Color(hex: "#ECECEC"), radius: 8.9, x: 0, y: 0)
                                
                                Image("pink-question-mark")
                                    .resizable()
                                    .frame(width: 11, height: 16)
                            }
                        )
                        .zIndex(1)
                    
                    avatarCircle(imageName: "pony-lady", size: 47.5, color: Color(hex: "#FED5B9"))
                        .zIndex(2)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .foregroundStyle(.grayScale10)
                    .shadow(color: Color(hex: "ECECEC"), radius: 9.0, x: 0, y: 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(lineWidth: 0.25)
                    .foregroundStyle(.grayScale60)
            )
        }
    }
    
    @ViewBuilder
    func avatarCircle(imageName: String, size: CGFloat, color: Color) -> some View {
        Circle()
            .frame(width: size, height: size)
            .foregroundStyle(color)
            .overlay(
                Image(imageName)
                    .resizable()
                    
                    .frame(width: 47.5, height: 47.5)
                    
            )
            .clipShape(.circle)
            .overlay(
                Circle()
                    .stroke(lineWidth: 1.5)
                    .foregroundStyle(.grayScale10)
            )
            
            .shadow(color: Color(hex: "#ECECEC"), radius: 8.9, x: 0, y: 0)
    }
}

#Preview {
    CreateYourAvatarCard()
}
