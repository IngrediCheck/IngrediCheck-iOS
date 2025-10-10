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
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(hex: "91C206"), location: 0.17),   // start color at 20%
                                .init(color: Color(hex: "6B8E06"), location: 0.73)   // end color at 100%
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                            .shadow(
                                .inner(color: Color(hex: "99C712"), radius: 2.2, x: 3.5, y: -1)
                            )
                            .shadow(
                                .drop(color: Color(hex: "606060").opacity(0.28), radius: 2, x: 1, y: 4)
                            )
                    )
                    .rotationEffect(.degrees(17))
            )
    }
}

#Preview {
    GreenCircle()
}
