//
//  ChipsModel.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import Foundation

struct ChipsModel: Identifiable, Equatable {
    let id = UUID().uuidString
    var name: String
    var icon: String
}
