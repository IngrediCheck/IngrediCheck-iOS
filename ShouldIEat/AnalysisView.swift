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
    @State private var errorExtractingIngredientsList: Bool = false
    
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
                if let imageOCRText = self.imageOCRText {
                    if errorExtractingIngredientsList {
                        Text("Failed to extract ingredients list from this food label:")
                        Text("\(imageOCRText)")
                    } else {
                        ProgressView()
                            .onAppear {
                                Task {
                                    let ingredientsList =
                                        try await backend.extractIngredients(ocrText: imageOCRText)
                                    if let ingredientsList = ingredientsList {
                                        let analysisResponse =
                                            try await backend.generateRecommendation(
                                                ingredients: ingredientsList,
                                                userPreference: userPreferenceText)
                                        DispatchQueue.main.async {
                                            self.analysis = analysisResponse
                                        }
                                    } else {
                                        DispatchQueue.main.async {
                                            self.errorExtractingIngredientsList = true
                                        }
                                    }
                                }
                            }
                    }
                } else {
                    Text("This does not look like a valid food label:")
                    Text("\(self.imageOCRText ?? "Empty")")
                }
            }
        } else {
            ImageCaptureView(image: $image, imageOCRText: $imageOCRText)
        }
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
