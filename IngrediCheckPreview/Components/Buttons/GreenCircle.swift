//
//  GreenCircle.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 09/10/25.
//

import SwiftUI

struct GreenCircle: View {
    var body: some View {
        Image("right-arrow-rounded-edge")
            .frame(width: 32, height: 32)
            .padding(10)
            .background(
                Capsule()
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")], startPoint: .top, endPoint: .bottom)
                            .shadow(
                                .inner(color: Color(hex: "EDEDED").opacity(0.25), radius: 7.5, x: 2, y: 4)
                            )
                            .shadow(
                                .inner(color: Color(hex: "72930A"), radius: 5.7, x: 0, y: 4)
                            )
                            .shadow(
                                .drop(color: Color(hex: "C5C5C5").opacity(0.57), radius: 11, x: 0, y: 4)
                            )
                    )
                    
            )
            .overlay(
                Capsule()
                    .stroke(lineWidth: 1)
                    .foregroundStyle(.grayScale10)
                
            )
    }
}

#Preview {
    GreenCircle()
}
