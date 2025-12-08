//
//  RecentScansFullView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar on 15/11/25.
//

import SwiftUI

struct RecentScansFullView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isProductDetailPresented = false
    
    // Sample data - feedback: nil = uncertain, true = matched, false = unmatched
    private let scanItems: [Bool?] = [
        true,   // matched
        false,  // unmatched
        nil,    // uncertain
        false,  // unmatched
        true,   // matched
        false,  // unmatched
        nil     // uncertain
    ]
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(scanItems.enumerated()), id: \.offset) { index, feedback in
                        Button {
                            isProductDetailPresented = true
                        } label: {
                            RecentScansRow(feedback: feedback)
                        }
                        .buttonStyle(.plain)
                        
                        if index != scanItems.count - 1 {
                            Divider()
                                .padding(.vertical, 14)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(hex: "FFFFFF"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Recent Scans")
                        .font(ManropeFont.semiBold.size(18))
                        .foregroundStyle(.grayScale150)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.grayScale150)
                    }
                }
            }
        }
        .sheet(isPresented: $isProductDetailPresented) {
            ProductDetailView()
        }
    }
}

#Preview {
    RecentScansFullView()
}

