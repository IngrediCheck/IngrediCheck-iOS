//
//  TipJarView.swift
//  IngrediCheck
//
//  Created by Gunjan Haider on 23/07/25.
//

import SwiftUI

struct TipJarView: View {
    
    @StateObject var vm = TipJarViewModel()
    
    var body: some View {
        ZStack {
            
            Color.paletteAccent.opacity(0.15).ignoresSafeArea()
            
            VStack {
                Text("Support IngrediCheck")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 12)
                
                Text("If you're enjoying IngrediCheck and would like to support its development, consider leaving a tip. Your support helps keep IngrediCheck free and enables ongoing development!")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                ForEach(vm.productsArr) { product in
                    Button {
                        Task {
                            await vm.purchase(product)
                        }
                    } label: {
                        TipCard(description: product.description, price: product.displayPrice)
                    }

                    
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
    }
}

struct TipCard: View {
    let description: String
    let price: String

    var body: some View {
            HStack {
                Text(description)
                Spacer()
                Text(price)
            }
            .foregroundStyle(.black)
            .fontWeight(.medium)
            .padding()
            .padding(.vertical, 2)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 0.5)
            )
            .padding(.horizontal)
            .padding(.vertical, 4)
    }
}


#Preview {
    TipJarView()
}
