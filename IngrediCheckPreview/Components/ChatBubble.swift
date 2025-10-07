//
//  ChatBubble.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 06/10/25.
//

import SwiftUI

enum ChatRole {
    case user
    case assistant
}
    

struct ChatBubble: View {
    
    @State var role: ChatRole = .assistant
    
    var body: some View {
        ZStack(alignment: role == .assistant ? .topLeading : .bottomTrailing) {
            Text("What else did you want to avoid?")
                .padding(.vertical, 12)
                .padding(.horizontal, 17)
                .background(Color(hex: "#D9D9D9"), in: RoundedRectangle(cornerRadius: 16))
            
            Rectangle()
                .fill(Color(hex: "#D9D9D9"))
                .frame(width: 15, height: 20)
        }
    }
}

#Preview {
    ChatBubble()
}
