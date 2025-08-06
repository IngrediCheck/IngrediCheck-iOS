//
//  PreferenceListViewModel.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 05/08/25.
//

import Foundation

class PreferenceListViewModel: ObservableObject {
    @Published var textFieldText = ""
    @Published var textFieldPlaceholder = "Enter your preference here"
}
