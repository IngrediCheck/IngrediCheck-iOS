//
//  LetsGetStartedView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

struct LetsGetStartedView: View {
    @State var showSheet: Bool = false
    @State var goToSingleDietaryPreference: Bool = false
    @State var goToFamilyDietaryPreference: Bool = false
    var body: some View {
        ZStack {
            
            CustomBoolSheet(isPresented: $showSheet, cornerRadius: 34, heights: (min: 283, max: 284), content: {
                WhosThisFor {
                    goToSingleDietaryPreference = true
                } addFamilyPressed: {
                    
                }

            })
            
            VStack {
                Text("Let’s get started! Your IngrediFam will appear here as you set things up.")
                    .multilineTextAlignment(.center)
                
                NavigationLink(isActive: $goToSingleDietaryPreference) {
                    DietaryPreferencesAndRestrictions(isFamilyFlow: false)
                } label: {
                    EmptyView()
                }

            }
            .onAppear() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showSheet = true
                }
            }
        }
        
        
    }
}

#Preview {
    LetsGetStartedView()
}
