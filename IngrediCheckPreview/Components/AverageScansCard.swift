//
//  AverageScansCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 06/10/25.
//

import SwiftUI

struct AverageScansCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("128")
                .font(.system(size: 28, weight: .bold))
            
            Text("Avg. Scans")
                .font(ManropeFont.medium.size(8))
                .foregroundStyle(.grayScale100)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .frame(width: 159, height: 149)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        AverageScansCard()
    }
}
