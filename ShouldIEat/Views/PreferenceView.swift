//
//  PreferenceView.swift
//  ShouldIEat
//
//  Created by sanket patel on 8/29/23.
//

import SwiftUI

struct PreferenceView: View {

    @Binding var preferenceText: String
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        TextEditor(text: $preferenceText)
            .focused($isTextEditorFocused)
            .padding()
            .overlay(
                Text("Enter your dietary preferences in plain English here.")
                    .foregroundColor(.gray)
                    .opacity(preferenceText.isEmpty ? 1 : 0)
            )
            .overlay(
                Group {
                    if isTextEditorFocused {
                        Button(action: {
                            isTextEditorFocused = false
                        }) {
                            Text("Save")
                                .padding()
                        }
                        .padding()
                        .transition(.scale)
                    }
                }, alignment: .bottomTrailing
            )
            .padding(.top)
    }
}

struct PreferenceView_Previews: PreviewProvider {
    static var previews: some View {
        @State var text: String = ""
        PreferenceView(preferenceText: $text)
    }
}
