//
//  HeyThereScreen.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/11/25.
//

import SwiftUI

struct HeyThereScreen: View {
    
    var body: some View {
        
        VStack {
            Image("Ingredicheck-logo")
                .frame(width : 107.3 ,height: 36)
               .padding(.top,10)
               .padding(.bottom,44)
             
               
            
            
            
            Image("Iphone-image")
                .resizable()
                .frame(width: 238 ,height: 450)
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(
                            hex: "#FFFFFF"
                        ),
                        Color(
                            hex: "#F7F7F7"
                        )
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        
    }
}

#Preview {
    HeyThereScreen()
}
