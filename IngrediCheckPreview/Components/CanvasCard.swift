//
//  CanvasCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import SwiftUI


struct CanvasCard: View {
    
    @State var chips: [ChipsModel]? = nil
//    [
//        ChipsModel(name: "Peanuts", icon: "peanuts"),
//        ChipsModel(name: "Sesame", icon: "sesame"),
//        ChipsModel(name: "Wheat", icon: "wheat"),
//        ChipsModel(name: "Shellfish", icon: "shellfish")
//    ]
    
    @State var sectionedChips: [SectionedChipModel]? = [
        SectionedChipModel(title: "Animal-Based", chips: [
            ChipsModel(name: "Peanuts", icon: "peanuts"),
            ChipsModel(name: "Sesame", icon: "sesame"),
            ChipsModel(name: "Wheat", icon: "wheat"),
            ChipsModel(name: "Shellfish", icon: "shellfish")
        ]),
        SectionedChipModel(title: "Oils & Fats", chips: [
            ChipsModel(name: "Peanuts", icon: "peanuts"),
            ChipsModel(name: "Sesame with almonds (in moderation) (10g)", icon: "sesame"),
            ChipsModel(name: "Wheat", icon: "wheat"),
            ChipsModel(name: "Shellfish", icon: "shellfish")
        ]),
        SectionedChipModel(title: "Additives & Sweeteners", chips: [
            ChipsModel(name: "Peanuts", icon: "peanuts"),
            ChipsModel(name: "Sesame", icon: "sesame"),
            ChipsModel(name: "Shellfish", icon: "shellfish")
        ])
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image("allergies")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.grayScale110)
                    .frame(width: 18, height: 18)
                
                Text("allergies".capitalized)
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
                                        familyList: ["image 1", "image 2", "image 3"],
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
                                outlined: false
                            )
                        }
                    }
                }
            }
            
            HStack(spacing: 8) {
                Image("exlamation")
                    .resizable()
                    .frame(width: 16, height: 16)
                
                Text("Something else too, don't worry we'll ask later!")
                    .font(ManropeFont.regular.size(10))
                    .foregroundStyle(Color(hex: "#7F7F7F"))
                    .italic()
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
            .padding(.horizontal)
    }
}
