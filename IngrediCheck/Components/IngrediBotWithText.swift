//
//  IngrediBotWithText.swift
//  IngrediCheckPreview
//
//  Created on 13/11/25.
//

import SwiftUI

struct IngrediBotWithText: View {
    let text: String
    var viewDidAppear: (() -> Void)? = nil
    var delay: TimeInterval = 2.0
    
    var body: some View {
        VStack(spacing: 32) {
            // Robot image
            Image("ingrediBot")
                .resizable()
                .scaledToFit()
                .frame(width: 147, height: 147)
                .clipped()
            
            VStack(spacing: 24) {
                Text(text)
                    .font(NunitoFont.bold.size(20))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
        .onAppear() {
            if let viewDidAppear = viewDidAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    viewDidAppear()
                }
            }
        }
    }
}

#Preview {
    IngrediBotWithText(text: "Bringing your avatar to life... it's going to be awesome!")
}

