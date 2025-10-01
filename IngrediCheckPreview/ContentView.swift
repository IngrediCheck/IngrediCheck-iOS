//
//  ContentView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import SwiftUI

struct ContentView: View {
    let chips = ["Swift", "Kotlin", "JavaScript", "Rust is more good", "Python", "Go", "TypeScript", "Java", "C++"]

    var body: some View {
//        ScrollView {
        FlowLayout(horizontalSpacing: 4, verticalSpacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    HStack {
                        Image("sesame")
                        Text(chip)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.gray.opacity(0.2)))
                }
            }
            .padding()
//        }
    }
}


#Preview {
    ContentView()
}
