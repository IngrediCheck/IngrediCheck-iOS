//
//  BarcodeAnalysisView.swift
//  ShouldIEat
//
//  Created by sanket patel on 2/1/24.
//

import SwiftUI

import SwiftUI

struct HeaderImage: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable()
                 .aspectRatio(contentMode: .fit)
        } placeholder: {
            ProgressView()
        }
        .clipped()
    }
}

struct BarcodeAnalysisView: View {
    let barcode: String
    @Environment(WebService.self) var webService
    
    @State private var product: DTO.Product? = nil
    @State private var error: Error? = nil

    var body: some View {
        if let error = self.error {
            Text("Error: \(error.localizedDescription)")
        } else if let product = self.product {
            List {
                Section(header: Text("Header").hidden()) {
                    VStack {
                        if let url = product.images.first?.url {
                            HeaderImage(url: url)
                        }
                        if let brand = product.brand {
                            Text(brand)
                        }
                        Text(product.name)
                    }
                }
                ForEach(product.ingredients, id: \.self) { ingredient in
                    Text(ingredient.name.capitalized)
                        .listRowBackground(self.rowBackground(forItem: ingredient))
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
    
    private func rowBackground(forItem ingredient: DTO.Ingredient) -> Color {
        if let vegetarian = ingredient.vegetarian, !vegetarian {
            return .red
        }
        if let vegan = ingredient.vegan, !vegan {
            return .yellow
        }
        /*
        if let vegetarian = ingredient.vegetarian,
           let vegan = ingredient.vegan,
           vegetarian && vegan {
            return .green
        }
         */
        return .clear
    }
}
