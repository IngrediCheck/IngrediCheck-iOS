//
//  User.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 14/11/25.
//

import Foundation
import SwiftUI

struct UserModel: Identifiable {
    var id = UUID().uuidString
    var name: String
    var image: String
    var backgroundColor: Color?
    var allergies: [String] = []
    var intolerances: [String] = []
    var healthConditions: [String] = []
    var lifeStage: [String] = []
    var region: [String] = []
    var avoid: [String] = []
    var lifestyle: [String] = []
    var nutrition: [String] = []
    var ethical: [String] = []
    var taste: [String] = []
    
    init(id: String = UUID().uuidString, familyMemberName: String, familyMemberImage: String, backgroundColor: Color? = nil) {
        self.id = id
        self.name = familyMemberName
        self.image = familyMemberImage
        self.backgroundColor = backgroundColor
    }
}


struct FamilyResponse: Codable {
    let family: Family
    let members: [FamilyMember]
}

struct Family: Codable {
    let id: String
    let name: String
    let preferences: Preferences
}

struct FamilyMember: Codable {
    let memberId: String
    let name: String
    let preferences: Preferences
}


struct Preferences: Codable {
    var sections: [String: PreferenceValue] = [:]
    
    init() {
        self.sections = [:]
    }
    
    init(sections: [String: PreferenceValue]) {
        self.sections = sections
    }
}

enum PreferenceValue: Codable {
    case list([String])
    case nested([String: [String]])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let array = try? container.decode([String].self) {
            self = .list(array)
            return
        }

        if let dict = try? container.decode([String: [String]].self) {
            self = .nested(dict)
            return
        }

        throw DecodingError.typeMismatch(PreferenceValue.self,
            DecodingError.Context(codingPath: decoder.codingPath,
                                  debugDescription: "Unknown format"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .list(let arr):
            try container.encode(arr)

        case .nested(let dict):
            try container.encode(dict)
        }
    }
}
