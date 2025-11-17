//
//  BlankScreen.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

struct BlankScreen: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    
    var body: some View {
            VStack {
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.white)
                .frame(width: UIScreen.main.bounds.width * 0.9)
                .shadow(color: .gray.opacity(0.5), radius: 9, x: 0, y: 0)
            }
        .onAppear {
            coordinator.setCanvasRoute(.blankScreen)
        }
    }
}

#Preview {
    BlankScreen()
}
