//
//  Temp3.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 03/10/25.
//

import SwiftUI

struct Temp3: View {
    
    var body: some View {
        Circle()
            .foregroundStyle(
                .blue
                .gradient
                .shadow(.inner(color: .black, radius: 10, x: 0, y: 14))
                .shadow(.inner(color: .black, radius: 10, x: 0, y: -14))
            )
    }
}

#Preview {
    Temp3()
        .padding()
}
