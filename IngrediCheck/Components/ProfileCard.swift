//
//  ProfileCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/10/25.
//

import SwiftUI
	
struct ProfileCard: View {
    @State var isProfileCompleted: Bool = false
    var body: some View {
        ZStack {
            
            if isProfileCompleted {
                Circle()
                    .frame(width: 66, height: 66)
                    .foregroundStyle(Color(hex: "#ABAAAA").opacity(0.1))
                    .shadow(color: Color(hex: "#ECECEC"), radius: 9, x: 0, y: 0)
                    
                
                Circle()
                    .frame(width: 55, height: 55)
                    .foregroundStyle(.grayScale10)
                    .shadow(color: Color(hex: "#FBFBFB"), radius: 9, x: 0, y: 0)
                    
                
                Image("profile-ritika")
                    .resizable()
                    .frame(width: 55, height: 55)
                    .clipShape(.circle)
                
                    
            } else {
                // the below component is only for background shadow as this is in zstack so for shadow this component is placed on the back of the circle so that the shadow should not overlap the circle
                Text("611")
                    .font(NunitoFont.regular.size(12))
                    .frame(height: 9.86)
                    .foregroundStyle(.grayScale10)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 62)
                            .foregroundStyle(
                                .primary800.gradient.shadow(
                                    .inner(color: Color(hex: "#DAFF67").opacity(0.25), radius: 4, x: 1, y: 2.5)
                                )
                                .shadow(
                                    .drop(color: Color(hex: "C5C5C5"), radius: 3.4, x: 0, y: 4)
                                )
                            )
                    )
                    .padding(.top, 55)
                
                Circle()
                    .frame(width: 66, height: 66)
                    .foregroundStyle(.grayScale30)
                    .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
                    .overlay(
                        Circle()
                            .stroke(lineWidth: 0.5)
                            .foregroundStyle(.grayScale80)
                            .overlay(
                                Circle()
                                    .trim(from: 0, to: 0.6)
                                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                    .foregroundStyle(.primary700)
                                    .rotationEffect(.degrees(90))
                            )
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
                        RoundedRectangle(cornerRadius: 62)
                            .foregroundStyle(
                                .primary800.gradient.shadow(
                                    .inner(color: Color(hex: "#DAFF67").opacity(0.5), radius: 2, x: 0, y: 3)
                                )
                            )
                    )
                    .padding(.top, 60)
            }
        }
    }
}

#Preview {
    ProfileCard()
}
