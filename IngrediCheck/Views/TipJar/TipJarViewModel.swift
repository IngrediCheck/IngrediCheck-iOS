//
//  TipJarViewModel.swift
//  IngrediCheck
//
//  Created by Gunjan Haider on 23/07/25.
//

import Foundation
import StoreKit

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
                            print("🔁 Transaction update received: \(transaction.productID)")
                            await transaction.finish()
                        }
                    } catch {
                        print("⚠️ Failed to handle transaction update: \(error)")
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
            print("Error while fetching products from connect file: \(error)")
        }
    }
    
    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            
            switch result {
                
            case .success(let verification):
                switch verification {
                    
                case .verified(let transaction):
                    print("Purchase Successful: \(transaction.productID)")
                    await transaction.finish()
                    
                case .unverified(_, let error):
                    print("Unverified Purchase: \(error.localizedDescription)")
                }
                
            case .userCancelled:
                print("Purchase cancelled by the user.")
                
            case .pending:
                print("Purchase is pending.")
                
            @unknown default:
                print("Unknown purchase result.")
            }
            
        } catch {
            print("Failed to purchase the product: \(error.localizedDescription)")
        }
    }
}
