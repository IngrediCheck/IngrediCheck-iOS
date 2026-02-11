//
//  LastCard.swift
//  IngrediCheck
//
//  Created by Gaurav on 12/01/26.
//

import SwiftUI

struct LastCard: View {
    @State private var size: CGFloat = UIScreen.main.bounds.width * 0.3
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(Color(hex: "#D7EEB2"))
                .frame(width: 325, height: 252)
            
            Circle()
                .frame(width: size, height: size)
        }
    }
}

#Preview {
    LastCard()
}
