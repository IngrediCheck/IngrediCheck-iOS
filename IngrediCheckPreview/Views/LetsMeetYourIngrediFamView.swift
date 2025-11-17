//
//  LetsMeetYourIngrediFamView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 11/11/25.
//

import SwiftUI

struct LetsMeetYourIngrediFamView: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    
    var body: some View {
            VStack {
                Spacer()
                Text("Let's meet your IngrediFam")
                Spacer()
                Spacer()
                Spacer()
            }
        .onAppear {
            coordinator.setCanvasRoute(.letsMeetYourIngrediFam)
        }
    }
}

#Preview {
    LetsMeetYourIngrediFamView()
}
