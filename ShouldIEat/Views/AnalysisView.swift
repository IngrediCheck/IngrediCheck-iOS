//
//  AnalysisView.swift
//  ShouldIEat
//
//  Created by sanket patel on 8/29/23.
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

struct AnalysisView: View {
    
    let userPreferenceText: String

    @State private var capturedItem: CapturedItem?
    @State private var analysis: String?
    @State private var errorExtractingIngredientsList: Bool = false

    var body: some View {
        if let capturedItem = self.capturedItem {
            switch capturedItem {
            case .ingredientLabel(let label):
                LabelAnalysisView(ingredientLabel: label, userPreferenceText: userPreferenceText)
            case .barcode(let barcode):
                BarcodeAnalysisView(barcode: barcode, userPreferenceText: userPreferenceText)
            }
        } else {
            CaptureView(capturedItem: $capturedItem)
        }
    }
}
