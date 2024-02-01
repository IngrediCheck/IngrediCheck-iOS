//
//  BarcodeAnalysisView.swift
//  ShouldIEat
//
//  Created by sanket patel on 2/1/24.
//

import SwiftUI

struct BarcodeAnalysisView: View {
    let barcode: String
    @Environment(WebService.self) var webService
    
    @State private var product: DTO.Product? = nil
    @State private var error: Error? = nil

    var body: some View {
        if let error = self.error {
            Text("Error: \(error.localizedDescription)")
        } else if let product = self.product {
            VStack {
                VStack {
                    Text(product.brand)
                    Text(product.name)
                }
                .padding(.top)
                List(product.ingredients, id: \.self) { ingredient in
                    Text(ingredient.name)
                }
            }
        } else {
            VStack {
                Spacer()
                Text("Looking up \(barcode)")
                Spacer()
                ProgressView()
                Spacer()
            }
            .task {
                do {
                    self.product = try await webService.fetchProduct(barcode: barcode)
                } catch {
                    self.error = error
                }
            }
        }
    }
}
