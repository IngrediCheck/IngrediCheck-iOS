//
//  RecentScansFullView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar on 15/11/25.
//

import SwiftUI

struct RecentScansFullView: View {
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
        .navigationTitle("Recent Scans")
        .sheet(isPresented: $isProductDetailPresented) {
            ProductDetailView()
                .environment(AppNavigationCoordinator(initialRoute: .home))
        }
    }
}

#Preview {
    RecentScansFullView()
}

