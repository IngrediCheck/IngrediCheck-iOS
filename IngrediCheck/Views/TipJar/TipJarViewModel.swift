//
//  TipJarViewModel.swift
//  IngrediCheck
//
//  Created by Gunjan Haider on 23/07/25.
//

import Foundation
import StoreKit
import os

@MainActor
class TipJarViewModel: ObservableObject {
    @Published var productsArr = [Product]()
    
    init() {
        Task {
            await retriveProducts()
            
            Task.detached(priority: .background) {
                for await result in Transaction.updates {
                    do {
                        let transaction = try result.payloadValue
                        if transaction.revocationDate == nil {
                            Log.debug("TipJarViewModel", "🔁 Transaction update received: \(transaction.productID)")
                            await transaction.finish()
                        }
                    } catch {
                        Log.error("TipJarViewModel", "⚠️ Failed to handle transaction update: \(error)")
                    }
                }
            }
        }
    }
    
    func retriveProducts() async {
        do {
            let products = try await Product.products(for: Constants.tipJarIdentifiers).sorted(by: { $0.price < $1.price })
            productsArr = products
        } catch {
            Log.error("TipJarViewModel", "Error while fetching products from connect file: \(error)")
        }
    }
    
    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            
            switch result {
                
            case .success(let verification):
                switch verification {
                    
                case .verified(let transaction):
                    Log.debug("TipJarViewModel", "Purchase Successful: \(transaction.productID)")
                    await transaction.finish()
                    
                case .unverified(_, let error):
                    Log.error("TipJarViewModel", "Unverified Purchase: \(error.localizedDescription)")
                }
                
            case .userCancelled:
                Log.debug("TipJarViewModel", "Purchase cancelled by the user.")
                
            case .pending:
                Log.debug("TipJarViewModel", "Purchase is pending.")
                
            @unknown default:
                Log.debug("TipJarViewModel", "Unknown purchase result.")
            }
            
        } catch {
            Log.error("TipJarViewModel", "Failed to purchase the product: \(error.localizedDescription)")
        }
    }
}
