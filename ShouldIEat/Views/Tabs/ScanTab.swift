//
//  ScanTab.swift
//  ShouldIEat
//
//  Created by sanket patel on 2/6/24.
//

import SwiftUI

struct IngredientLabel: Hashable {
    let image: UIImage
    let imageOCRText: String
}

enum CapturedItem: Hashable {
    case barcode(String)
    case ingredientLabel(IngredientLabel)
}

struct ScanTab: View {
    @State private var routes: [CapturedItem] = []
    @State private var analysis: String?
    @State private var errorExtractingIngredientsList: Bool = false

    var body: some View {
        NavigationStack(path: $routes) {
            VStack {
                CaptureView(routes: $routes)
                Spacer()
                Divider()
                    .padding(.bottom)
            }
            .navigationDestination(for: CapturedItem.self) { item in
                switch item {
                    case .ingredientLabel(let label):
                        LabelAnalysisView(ingredientLabel: label)
                    case .barcode(let barcode):
                        BarcodeAnalysisView(barcode: barcode)
                }
            }
        }
    }
}

#Preview {
    ScanTab()
}
