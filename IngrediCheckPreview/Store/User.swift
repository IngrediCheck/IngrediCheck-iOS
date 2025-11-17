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
    let allergies: [String]? = nil
    let intolerances: [String]? = nil

    let region: RegionPreferences? = nil
    let avoid: AvoidPreferences? = nil
    let lifestyle: LifestylePreferences? = nil
    let nutrition: NutritionPreferences? = nil

    let ethical: [String]? = nil
    let taste: [String]? = nil
    let miscellaneousNotes: [String]? = nil

    let healthConditions: [String]? = nil
    let lifeStage: [String]? = nil

    enum CodingKeys: String, CodingKey {
        case allergies = "Allergies"
        case intolerances = "Intolerances"
        case region = "Region"
        case avoid = "Avoid"
        case lifestyle = "Lifestyle"
        case nutrition = "Nutrition"
        case ethical = "Ethical"
        case taste = "Taste"
        case miscellaneousNotes = "MiscellaneousNotes"
        case healthConditions = "Health Conditions"
        case lifeStage = "Life Stage"
    }
}

struct RegionPreferences: Codable {
    let indiaSouthAsia: [String]
    let africa: [String]
    let eastAsian: [String]
    let middleEastMediterranean: [String]
    let westernNative: [String]
    let seventhDayAdventist: [String]
    let other: [String]

    enum CodingKeys: String, CodingKey {
        case indiaSouthAsia = "India & South Asia"
        case africa = "Africa"
        case eastAsian = "East Asian"
        case middleEastMediterranean = "Middle East and Mediterranean"
        case westernNative = "Western / Native traditions"
        case seventhDayAdventist = "Seventh-day Adventist"
        case other = "Other"
    }
}


struct AvoidPreferences: Codable {
    let oilsFats: [String]
    let animalBased: [String]
    let stimulantsSubstances: [String]
    let additivesSweeteners: [String]
    let plantBasedRestrictions: [String]

    enum CodingKeys: String, CodingKey {
        case oilsFats = "Oils & Fats"
        case animalBased = "Animal Based"
        case stimulantsSubstances = "Stimulants and Substances"
        case additivesSweeteners = "Additives and Sweeteners"
        case plantBasedRestrictions = "Plant-Based Restrictions"
    }
}

struct LifestylePreferences: Codable {
    let plantBalance: [String]
    let qualitySource: [String]
    let sustainableLiving: [String]

    enum CodingKeys: String, CodingKey {
        case plantBalance = "Plant & Balance"
        case qualitySource = "Quality & Source"
        case sustainableLiving = "Sustainable Living"
    }
}

struct NutritionPreferences: Codable {
    let macronutrientGoals: [String]
    let sugarFiber: [String]
    let dietFrameworks: [String]

    enum CodingKeys: String, CodingKey {
        case macronutrientGoals = "Macronutrient Goals"
        case sugarFiber = "Sugar & Fiber"
        case dietFrameworks = "Diet Frameworks & Patterns"
    }
}
