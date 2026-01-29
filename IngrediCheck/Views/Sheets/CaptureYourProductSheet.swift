//
//  CaptureYourProductSheet.swift
//  IngrediCheck
//
//  Created on [Date].
//

import SwiftUI

struct CaptureYourProductSheet: View {
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    // Drag indicator
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray4))
                        .frame(width: 72, height: 4)
                        .padding(.top, 12)
                    
                    // Title
                    Text("Capture your product 📸")
                        .font(NunitoFont.bold.size(24))
                        .foregroundColor(.grayScale150)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    // Description
                    Text("We'll guide you through a few angles so our AI can identify the product and its ingredients accurately.")
                        .font(ManropeFont.medium.size(12))
                        .foregroundColor(Color(.grayScale120))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                
                // Illustration
                ZStack {
                    Image("systemuiconscapture")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 187, height: 187)
                    Image("takeawafood")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 94, height: 110)
                }
                
                // Additional info
                Text("You'll take around 5 photos — front, back, barcode, and ingredient list.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(.grayScale110))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.lightGray))
                    .padding(12)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 431)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(radius: 20)
        .padding(.horizontal, 8)
        .padding(.bottom, 0)
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.35)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            
            CaptureYourProductSheet(onDismiss: {})
        }
    }
}
