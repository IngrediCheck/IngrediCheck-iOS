//
//  HeyThereScreen.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/11/25.
//

import SwiftUI

struct HeyThereScreen: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Hey There 👋")
                .font(NunitoFont.bold.size(32))
                .foregroundStyle(.grayScale150)
            
            Text("IngrediBot will help you get set up in a minute or two.")
                .font(ManropeFont.medium.size(16))
                .foregroundStyle(.grayScale110)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            Image("ingrediBot")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onAppear {
            coordinator.setCanvasRoute(.heyThere)
        }
    }
}

#Preview {
    HeyThereScreen()
}
