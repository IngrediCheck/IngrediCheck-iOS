//
//  UserFeedbackCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 08/10/25.
//

import SwiftUI

struct UserFeedbackCard: View {
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    
                    Image("rohank")
                        .resizable()
                        .frame(width: 21, height: 21)
                        .clipShape(.circle)
                        .shadow(color: Color(hex: "B6B6B6"), radius: 3.9, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .stroke(lineWidth: 1)
                                .foregroundStyle(Color(hex: "EBEBEB"))
                        )
                    
                    Text("Rohan K.")
                        .font(ManropeFont.bold.size(14))
                        .foregroundStyle(Color(hex: "2E2E2E"))
                }
                
                VStack() {
                    Text("Super easy ")
                    +
                    Text(
                        Image(systemName: "barcode.viewfinder")
                    )
                    +
                    Text(" barcode scan, ")
                        .foregroundStyle(.grayScale90)
                    +
                    Text("very helpful.")
                }
                
                Divider()
                    .padding(.horizontal, 12)
                
                HStack(spacing: 3) {
                    Text("4.8")
                    
                    Image("yellow-star")
                    
                    RoundedRectangle(cornerRadius: 10)
                        .frame(width: 1, height: 12)
                    
                    Text("85K+")
                }
                .font(ManropeFont.light.size(14))
                .foregroundStyle(.grayScale120)
            }
            .font(ManropeFont.semiBold.size(12))
            .frame(width: 159, height: 141)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .foregroundStyle(.grayScale10)
            )
            
            Image("lays")
                .resizable()
                .frame(width: 13.56, height: 19.81)
                .cornerRadius(3)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(lineWidth: 1)
                        .foregroundStyle(Color(hex: "ECECEC"))
                )
                .rotationEffect(Angle(degrees: 20))
                .shadow(color: Color(hex: "DEDEDE"), radius: 3.4, x: 1, y: 3)
                .offset(x: 50,y: 5)
                
        }
    }
}

#Preview {
    ZStack {
        Color(.gray).opacity(0.2).ignoresSafeArea()
        UserFeedbackCard()
    }
}
