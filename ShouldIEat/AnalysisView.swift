//
//  AnalysisView.swift
//  ShouldIEat
//
//  Created by sanket patel on 8/29/23.
//

import SwiftUI

struct AnalysisView: View {
    
    @Binding var userPreferenceText: String
    @Binding var savedImage: UIImage?
    @Binding var savedAnalysis: String?
    
    @State private var image: UIImage?
    @State private var imageOCRText: String?
    @State private var analysis: String?
    
    var backend = Backend()

    var body: some View {
        if let image = self.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding()
                .onAppear { self.savedImage = image }
            if let analysis = self.analysis {
                Text(analysis)
                    .onAppear { self.savedAnalysis = analysis }
            } else {
                if let ingredientsList = self.ingredientsList {
                    ProgressView()
                        .onAppear {
                            Task {
                                let analysisResponse =
                                    try await backend.generateRecommendation(
                                        ingredients: ingredientsList,
                                        userPreference: userPreferenceText)
                                DispatchQueue.main.async {
                                    self.analysis = analysisResponse
                                }
                            }
                        }
                } else {
                    Text("This does not look like a valid Ingredients list:")
                    Text("\(self.imageOCRText ?? "Empty")")
                }
            }
        } else {
            ImageCaptureView(image: $image, imageOCRText: $imageOCRText)
        }
    }
    
    private var ingredientsList: String? {
        extractIngredients(from: self.imageOCRText)
    }
    
    func extractIngredients(from ocrText: String?) -> String? {
        
        guard let ocrText = ocrText else {
            return nil
        }

        guard let range = ocrText.range(of: "INGREDIENTS") else {
            print("No ingredients list found.")
            return nil
        }
        
        let ingredientsString = ocrText[range.upperBound...]
//        let endIndex = ingredientsString.firstIndex(of: ".") ?? ingredientsString.endIndex

//        return String(ingredientsString[..<endIndex])
        return String(ingredientsString)
    }
}

struct AnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        @State var userPreferenceText: String = ""
        @State var lastSavedImage: UIImage?
        @State var lastSavedAnalysis: String?
        AnalysisView(userPreferenceText: $userPreferenceText,
                     savedImage: $lastSavedImage,
                     savedAnalysis: $lastSavedAnalysis)
    }
}
