//
//  ToastView.swift
//  IngrediCheck
//
//  Created by Auto-Agent on 09/01/26.
//

import SwiftUI

struct ToastView: View {
    let data: ToastData
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: data.type.icon)
                .font(.system(size: 20))
                .foregroundColor(data.type.color)
            
            Text(data.message)
                .font(ManropeFont.medium.size(14))
                .foregroundColor(.black)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
        .onTapGesture {
            onDismiss()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        
        VStack {
            ToastView(
                data: ToastData(message: "Something went wrong. Please try again.", type: .error, duration: 3),
                onDismiss: {}
            )
            
            ToastView(
                data: ToastData(message: "Family created successfully!", type: .success, duration: 3),
                onDismiss: {}
            )
        }
    }
}
