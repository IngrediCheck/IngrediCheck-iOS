//
//  IngrediBotView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 30/10/25.
//

import SwiftUI

struct IngrediBotView: View {
    @State var other: Bool = true
    var body: some View {
        VStack(spacing: 0) {
            // Bot illustration
            Image("ingrediBot")
                .resizable()
                .scaledToFit()
                .frame(width: 187, height: 176)
                .rotationEffect(Angle(degrees: 10))

            // Greeting line
            (
                Text("Hey! 👋 I'm ")
                    .font(NunitoFont.semiBold.size(16))
                    .foregroundStyle(.grayScale100)
                + Text("IngrediBot,")
                    .font(NunitoFont.semiBold.size(16))
                    .foregroundStyle(.primary700)
            )
            .padding(.top, 4)

            // Title
            Text("How about making food choices easier together?")
                .font(NunitoFont.bold.size(20))
                .multilineTextAlignment(.center)
                .foregroundStyle(.grayScale150)
                .padding(.top, 12)

            Spacer(minLength: 40)
            
            Text("Shall we get started?")
                .font(NunitoFont.medium.size(20))
                .foregroundStyle(.grayScale110)
                .padding(.bottom, 8)

            // Sub header
            if other {
                Group {
                    Text("I noticed you selected")
                        .font(NunitoFont.regular.size(14))
                        .foregroundStyle(.grayScale110)
                         +
                         Text(" \"Other\" ")
                        .font(NunitoFont.bold.size(14))
                        .foregroundStyle(.grayScale140)
                         +
                         Text("earlier, that's great!\nCould you tell me a bit more about it?")
                        .font(NunitoFont.regular.size(14))
                        .foregroundStyle(.grayScale110)
                }
                .multilineTextAlignment(.center)
            } else {
                Text("\"Tell me a bit about what kind of food experience you'd love here.\"")
                    .font(NunitoFont.regular.size(14))
                    .foregroundStyle(.grayScale110)
                    .multilineTextAlignment(.center)
            }
            

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    
                } label: {
                    Text("Maybe later")
                        .lineLimit(1)
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 17)
                        .frame(width: 159, height: 52)
                        .background(.grayScale40, in: .capsule)
                }
                

                GreenCapsule(title: "Yes, let's go", icon: nil, width: 152, height: 52)
            }
            .padding(.top, 33)

            Text("No problem! You can come back anytime — I'll be here when you're ready.")
                
                .font(ManropeFont.regular.size(12))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: "B6B6B6"))
                .padding(.top, 13)
                .padding(.horizontal, -2)
                .padding(.horizontal, 1)
                

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 20)
        
    }
}

#Preview {
    IngrediBotView()
}
