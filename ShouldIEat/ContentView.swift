//
//  ContentView.swift
//  ShouldIEat
//
//  Created by sanket patel on 8/28/23.
//

import SwiftUI

struct AnalyzedItem : Identifiable {
    var id = UUID()
    var Image: UIImage
    var Analysis: String
}

struct ContentView: View {
    @AppStorage("userPreferenceText") var userPreferenceText: String = ""
    @State private var analyzedItems: [AnalyzedItem] = []
    @State private var showAnalysisSheet: Bool = false
    @State private var showPreferenceSheet: Bool = false

    var body: some View {
        VStack {
            List(analyzedItems.reversed()) { item in
                Image(uiImage: item.Image)
                    .resizable()
                    .scaledToFit()
                Text(item.Analysis)
                    .padding()
            }
            Spacer()
            HStack {
                Spacer()
                Button("Should I Eat?".uppercased()) {
                    self.showAnalysisSheet = true
                }
                .padding()
                .background(Color.accentColor)
                .foregroundColor(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                Spacer()
                Button("Dietary Preference") {
                    self.showPreferenceSheet = true
                }
                .padding()
                .background(Color.accentColor)
                .foregroundColor(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                Spacer()
            }
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showAnalysisSheet) {
            AnalysisView(userPreferenceText: $userPreferenceText,
                         analyzedItems: $analyzedItems)
        }
        .sheet(isPresented: $showPreferenceSheet) {
            PreferenceView(preferenceText: $userPreferenceText)
                .presentationDetents([.medium])
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
