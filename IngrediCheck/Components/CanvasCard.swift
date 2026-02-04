//
//  CanvasCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import SwiftUI


struct CanvasCard: View {
    @Environment(FamilyStore.self) private var familyStore
    
    var chips: [ChipsModel]? = [
        ChipsModel(name: "Peanuts", icon: "🥜"),
        ChipsModel(name: "Sesame", icon: "❤️"),
        ChipsModel(name: "Wheat", icon: "🌾"),
        ChipsModel(name: "Shellfish", icon: "🦐")
    ]
    
    var sectionedChips: [SectionedChipModel]? = nil
    
    var title: String = "allergies"
    var iconName: String = "allergies"
    var itemMemberAssociations: [String: [String: [String]]] = [:]
    var showFamilyIcons: Bool = true
    
    // Helper function to get member identifiers for an item
    // Returns "Everyone" or member UUID strings for use in ChipMemberAvatarView
    private func getMemberIdentifiers(for sectionName: String, itemName: String) -> [String] {
        guard let memberIds = itemMemberAssociations[sectionName]?[itemName] else {
            return []
        }
        
        // Return member IDs directly (already UUID strings or "Everyone")
        // ChipMemberAvatarView will resolve these to FamilyMember objects
        return memberIds
    }
    
    private var hasOtherSelected: Bool {
        if let chips = chips, chips.contains(where: { $0.name == "Other" }) {
            return true
        }
        if let sectionedChips = sectionedChips, sectionedChips.contains(where: { section in
            section.chips.contains(where: { $0.name == "Other" })
        }) {
            return true
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(iconName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.grayScale110)
                    .frame(width: 18, height: 18)
                
                Text(title.capitalized)
                    .font(NunitoFont.semiBold.size(14))
                    .foregroundStyle(.grayScale110)
            }
            .fontWeight(.semibold)
            
            VStack(alignment: .leading) {
                
                if let sectionedChips = sectionedChips {
                    ForEach(sectionedChips) { ele in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(ele.title)
                                .font(ManropeFont.semiBold.size(12))
                                .foregroundStyle(.grayScale150)
                            
                            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                                ForEach(ele.chips) { chip in
                                    IngredientsChips(
                                        title: chip.name,
                                        bgColor: .secondary200,
                                        image: chip.icon,
                                        familyList: showFamilyIcons ? getMemberIdentifiers(for: title, itemName: chip.name) : [],
                                        outlined: false
                                    )
                                }
                            }
                        }
                    }
                } else if let chips = chips {
                    FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(chips, id: \.id) { chip in
                            IngredientsChips(
                                title: chip.name,
                                bgColor: .secondary200,
                                image: chip.icon,
                                familyList: showFamilyIcons ? getMemberIdentifiers(for: title, itemName: chip.name) : [],
                                outlined: false
                            )
                        }
                    }
                }
            }
            
            if hasOtherSelected {
                HStack(spacing: 8) {
                    Image("exlamation")
                        .resizable()
                        .frame(width: 16, height: 16)

                    Microcopy.text(Microcopy.Key.Onboarding.Dynamic.otherSelectedNote)
                        .font(ManropeFont.regular.size(10))
                        .foregroundStyle(Color(hex: "#7F7F7F"))
                        .italic()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.white)
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 0.25)
                .foregroundStyle(.grayScale60)
        )
        
    }
}

#Preview {
    ZStack {
//        Color.gray.opacity(0.3).ignoresSafeArea()
        CanvasCard()
            .padding(.horizontal, 20)
    }
}
