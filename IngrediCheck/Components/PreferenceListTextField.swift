//
//  PreferenceListTextField.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 05/08/25.
//

import SwiftUI

struct PreferenceListTextField: View {
    @State var text: Binding<String>
    @State var placeholderText: String
    var body: some View {
            TextField(placeholderText, text: text)
                .padding()
                .background(.primary50)
                .cornerRadius(8)
                .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 5)
    }
}

//#Preview {
//    PreferenceListTextField()
//}
