//
//  ContentView.swift
//  ShouldIEat
//
//  Created by sanket patel on 8/28/23.
//

import SwiftUI

struct MyTextEditor: View {

    @Binding var text: String
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        TextEditor(text: $text)
            .focused($isTextEditorFocused)
            .frame(height: 150)
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 1)
            )
            .padding()
            .overlay(
                Text("Enter your dietary preferences in plain English here.")
                    .foregroundColor(.gray)
                    .opacity(text.isEmpty ? 1 : 0)
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

struct AnalyzedItem : Identifiable {
    var id = UUID()
    var Image: UIImage
    var Analysis: String
}

struct ContentView: View {
    @AppStorage("userPreferenceText") var userPreferenceText: String = ""
    @State private var analyzedItems: [AnalyzedItem] = []
    @State private var showAnalysisSheet: Bool = false

    var body: some View {
        VStack {
            MyTextEditor(text: $userPreferenceText)
            List(analyzedItems.reversed()) { item in
                Image(uiImage: item.Image)
                    .resizable()
                    .scaledToFit()
                Text(item.Analysis)
                    .padding()
            }
            Spacer()
            Button("Should I Eat?".uppercased()) {
                self.showAnalysisSheet = true
            }
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showAnalysisSheet) {
            AnalysisView(userPreferenceText: $userPreferenceText,
                         analyzedItems: $analyzedItems)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
