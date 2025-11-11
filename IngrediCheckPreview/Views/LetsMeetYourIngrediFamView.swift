//
//  LetsMeetYourIngrediFamView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 11/11/25.
//

import SwiftUI

enum LetsMeetYourIngrediFamSheetOption: String, Identifiable {
    case letsMeetYourIngrediFam
    case whatsYourName
    case addMoreMembers
    case addMoreMembersMinimal
    case generateAvatar
    case bringingYourAvatar
    case meetYourAvatar
    
    var id: String {
        return self.rawValue
    }
}

struct LetsMeetYourIngrediFamView: View {
    var body: some View {
        ZStack {
            
            
            
            VStack {
                RoundedRectangle(cornerRadius: 24)
                    .foregroundStyle(.white)
                    .frame(width: UIScreen.main.bounds.width * 0.9)
                    .shadow(color: .gray.opacity(0.5), radius: 9, x: 0, y: 0)
            }
            
            VStack {
                Spacer()
                Text("Let's meet your IngrediFam")
                
                Spacer()
                Spacer()
                Spacer()
            }
        }
    }
}

#Preview {
    LetsMeetYourIngrediFamView()
}
