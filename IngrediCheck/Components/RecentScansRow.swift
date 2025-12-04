//
//  RecentScansRow.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 06/10/25.
//

import SwiftUI

struct RecentScansRow: View {
    
    @State var feedback: Bool? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Image("corn-flakes")
                .resizable()
                .scaledToFill()
                .frame(width: 42, height: 42)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Kellogg's Corn Flakes")
                    .font(ManropeFont.bold.size(12))
                    .foregroundStyle(.teritairy1000)
                
                Text("30 minutes ago")
                    .font(ManropeFont.regular.size(12))
                    .foregroundStyle(.grayScale100)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(feedback == nil ? Color(hex: "#FCDE00") : feedback == true ? .primary600 : Color(hex: "#FF1100"))
                    .frame(width: 10, height: 10)
                
                Text(feedback == nil ? "Uncertain" : feedback == true ? "Matched" : "Unmatched")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(feedback == nil ? Color(hex: "#FF594E") : feedback == true ? .primary600 : Color(hex: "#FF1100"))
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(feedback == nil ? Color(hex: "#FFF9CE") : feedback == true ? .primary200 : Color(hex: "#FFE3E2"), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    RecentScansRow()
        .padding(.horizontal, 20)
}
