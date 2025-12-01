//
//  TempStore.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 14/10/25.
//

import SwiftUI

struct TempStore: View {
    @StateObject var store = Onboarding(onboardingFlowtype: .individual)
    @State var preferences: Preferences = Preferences()
    var body: some View {
        VStack {
            store.currentScreen.buildView(store.onboardingFlowtype, $preferences)
            
            let _ = print("render")
            
            Text("Progress: \(store.progress * 100)")
            Text("Tag: \(store.currentScreen.screenId.rawValue)")
            
            Button("Next") {
                store.next()
            }
            
            Button("change") {
                store.onboardingFlowtype = .family
            }
        }
    }
}

#Preview {
    TempStore()
}
