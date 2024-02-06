//
//  ScanTab.swift
//  ShouldIEat
//
//  Created by sanket patel on 2/6/24.
//

import SwiftUI

struct IngredientLabel {
    let image: UIImage
    let imageOCRText: String
}

enum CapturedItem {
    case barcode(String)
    case ingredientLabel(IngredientLabel)
}

struct ScanTab: View {
    @State private var capturedItem: CapturedItem?
    @State private var analysis: String?
    @State private var errorExtractingIngredientsList: Bool = false

    var body: some View {
        VStack {
            if let capturedItem = self.capturedItem {
                switch capturedItem {
                case .ingredientLabel(let label):
                    LabelAnalysisView(ingredientLabel: label)
                case .barcode(let barcode):
                    BarcodeAnalysisView(barcode: barcode)
                }
            } else {
                CaptureView(capturedItem: $capturedItem)
            }
            Spacer()
            Divider()
                .padding(.bottom)
        }
    }
}

#Preview {
    ScanTab()
}
