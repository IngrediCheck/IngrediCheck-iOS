//
//  WelcomeToYourFamilyView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

struct WelcomeToYourFamilyView: View {
    
    @State var showSheet: Bool = false
    @State var goToHome: Bool = false
    
    var body: some View {
        ZStack {
            
            CustomBoolSheet(isPresented: $showSheet, cornerRadius: 34, heights: (min: 283, max: 284), content: {
                AllSetToJoinYourFamily {
                    showSheet = false
                    goToHome = true
                }
            })
            
            VStack {
                Group {
                    Text("Welcome to your family,")
                    Text("Patel Family! 👋")
                }
                .font(NunitoFont.bold.size(22))
                .foregroundStyle(.grayScale150)
                
                Text("You’re now part of this shared space — where everyone’s preferences and safety come together.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
                
                NavigationLink(destination: HomeView(), isActive: $goToHome) {
                    EmptyView()
                }
                
                Spacer()
            }
            .onAppear() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    showSheet = true
                }
            }
        }
        
    }
}

#Preview {
    WelcomeToYourFamilyView()
}
