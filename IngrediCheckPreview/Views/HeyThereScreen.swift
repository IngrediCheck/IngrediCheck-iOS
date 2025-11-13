//
//  HeyThereScreen.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/11/25.
//

import SwiftUI

enum HeyThereScreenSheetOptions: String, CaseIterable, Identifiable {
    case alreadyHaveAnAccount
    case welcomeBack
    
    var id: String { self.rawValue }
}

struct HeyThereScreen: View {
    
    @State var heyThereScreenSheetOption: HeyThereScreenSheetOptions? = nil
    
    var body: some View {
        ZStack {
            
           CustomSheet(item: $heyThereScreenSheetOption, cornerRadius: 34, heightsForItem: { sheet in
               switch sheet {
               case .alreadyHaveAnAccount: return (min: 274, max: 275)
               case .welcomeBack: return (min: 290, max: 291)
               }
           }, content: { sheet in
               switch sheet {
                   
               case .alreadyHaveAnAccount: AlreadyHaveAnAccount()

               case .welcomeBack: WelcomeBack()
                   
               }
           })
            
            VStack {
                Text("Hey There 👋")
            }
            .onAppear() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    heyThereScreenSheetOption = .alreadyHaveAnAccount
                }
                
            }
            
            
        }
    }
}

#Preview {
    HeyThereScreen()
}
