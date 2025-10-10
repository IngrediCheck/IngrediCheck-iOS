//
//  FamilyCarouselModel.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 01/10/25.
//

import Foundation
import SwiftUI

struct FamilyMemberModel: Identifiable {
    var id = UUID().uuidString
    let familyMemberName: String
    let familyMemberImage: String
    let backgroundColor: Color?
    
    init(id: String = UUID().uuidString, familyMemberName: String, familyMemberImage: String, backgroundColor: Color? = nil) {
        self.id = id
        self.familyMemberName = familyMemberName
        self.familyMemberImage = familyMemberImage
        self.backgroundColor = backgroundColor
    }
}
