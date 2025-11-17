//
//  LetsGetStartedView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

struct LetsGetStartedView: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    
    var body: some View {
            VStack {
            Text("Let's get started! Your IngrediFam will appear here as you set things up.")
                    .multilineTextAlignment(.center)
            }
        .onAppear {
            coordinator.setCanvasRoute(.letsGetStarted)
        }
    }
}

#Preview {
    LetsGetStartedView()
}
