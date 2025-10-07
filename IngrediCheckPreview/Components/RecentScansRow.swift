//
//  RecentScansRow.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 06/10/25.
//

import SwiftUI

struct RecentScansRow: View {
    
    @State var feedback: Bool? = true
    
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
            
            if let feedback {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.primary600)
                        .frame(width: 10, height: 10)
                    
                    Text("Matched")
                        .font(ManropeFont.semiBold.size(10))
                        .foregroundStyle(.primary600)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(.primary300, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

#Preview {
    RecentScansRow()
        .padding(.horizontal, 20)
}
