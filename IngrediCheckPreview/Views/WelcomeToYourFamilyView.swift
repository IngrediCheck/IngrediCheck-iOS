//
//  WelcomeToYourFamilyView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

struct WelcomeToYourFamilyView: View {
    
    var body: some View {
        VStack {
            Group {
                Text("Welcome to your family,")
                Text("Patel Family! 👋")
            }
            .font(NunitoFont.bold.size(22))
            .foregroundStyle(.grayScale150)
            
            Text("You're now part of this shared space — where everyone's preferences and safety come together.")
                .font(ManropeFont.medium.size(12))
                .foregroundStyle(.grayScale120)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
}

#Preview {
    WelcomeToYourFamilyView()
}
