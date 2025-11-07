//
//  HeyThereScreen.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/11/25.
//

import SwiftUI

struct HeyThereScreen: View {
    @State var isShown: Bool = false
    var body: some View {
        ZStack {
            
            CustomBoolSheet(isPresented: $isShown, cornerRadius: 34, heights: (min: 270, max: 400)) {
                Text("Hii")
            }
            
            VStack {
                Text("Hey There 👋")
                Button("toggle") {
                    isShown.toggle()
                }
            }
            .onAppear() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isShown = true
                }
                
            }
            
            
        }
    }
}

#Preview {
    HeyThereScreen()
}
