//
//  YourBarcodeScans.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 08/10/25.
//

import SwiftUI

struct YourBarcodeScans: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Barcode Scans")
                    .font(ManropeFont.regular.size(14))
                    .foregroundStyle(.grayScale110)
                
                Text("50")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.grayScale150)
                    .frame(height: 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 4) {
                Image("your-barcode-scan")
                    .resizable()
                    .frame(width: 12, height: 12)
                    
                Text("Scan")
                    .font(NunitoFont.semiBold.size(10))
                    .foregroundStyle(.grayScale10)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 13)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .foregroundStyle(
                        .primary800
                        .gradient
                        .shadow(
                            .inner(color: Color(hex: "#DAFF67").opacity(0.25), radius: 7.3, x: 2, y: 9)
                        )
                        .shadow(
                            .inner(color: Color(hex: "#A2D20C"), radius: 5.7, x: 0, y: 4)
                        )
                    )
                    .shadow(color: Color(hex: "#C5C5C5").opacity(0.57), radius: 11, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(lineWidth: 1)
                    .foregroundStyle(.grayScale10)
            )
        }
        .padding(12)
        .frame(height: UIScreen.main.bounds.height * 0.18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(.grayScale10)
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
        )
        .overlay(
            Image("scan-card-jar")
                .clipShape(RoundedRectangle(cornerRadius: 20))
            , alignment: .bottomTrailing
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(lineWidth: 0.25)
                .foregroundStyle(.grayScale60)
        )
    }
}

#Preview {
    ZStack {
        YourBarcodeScans()
    }
}
