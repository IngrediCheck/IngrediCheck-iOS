//
//  PreferenceListViewModel.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 05/08/25.
//

import Foundation

enum PreferenceListActiveSheets: Identifiable {
    case createNewList
    case editList
    case listFeatures
    case share
    
    var id: String {
        switch self {
        case .createNewList:
            return "createNewList"
        case .editList:
            return "editList"
        case .listFeatures:
            return "listFeatures"
        case .share:
            return "share"
        }
    }
    
}

class PreferenceListViewModel: ObservableObject {
    @Published var textFieldText = ""
    @Published var textFieldPlaceholder = "Enter your preference here"
}
