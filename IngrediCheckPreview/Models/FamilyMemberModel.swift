//
//  FamilyCarouselModel.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 01/10/25.
//

import Foundation

struct FamilyMemberModel: Identifiable, Hashable, Codable {
    var id = UUID().uuidString
    let familyMemberName: String
    let familyMemberImage: String
}
