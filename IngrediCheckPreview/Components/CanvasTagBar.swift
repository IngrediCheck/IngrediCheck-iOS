//
//  CanvasTagBar.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 03/10/25.
//

import SwiftUI

struct CanvasTagBar: View {
    
    @State var iconsArr: [ChipsModel] = [
        ChipsModel(name: "Allergies", icon: "allergies"),
        ChipsModel(name: "Intolerances", icon: "mingcute_alert-line"),
        ChipsModel(name: "Health Conditions", icon: "lucide_stethoscope"),
        ChipsModel(name: "Life Stage", icon: "lucide_baby"),
        ChipsModel(name: "Region", icon: "nrk_globe"),
        ChipsModel(name: "Avoid", icon: "charm_circle-cross"),
        ChipsModel(name: "Life Style", icon: "hugeicons_plant-01"),
        ChipsModel(name: "Nutrition", icon: "fluent-emoji-high-contrast_fork-and-knife-with-plate"),
        ChipsModel(name: "Ethical", icon: "streamline_recycle-1-solid"),
        ChipsModel(name: "Taste", icon: "iconoir_chocolate")
    ]
    @State var selectedTag: ChipsModel = ChipsModel(name: "Allergies", icon: "allergies")
    @State var visited: [String] = []
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -1) {
                ForEach(iconsArr) { model in
                    TagIconCapsule(
                        image: model.icon ?? "",
                        title: model.name,
                        isSelected: $selectedTag.name,
                        isFirst: (model.name == iconsArr.first?.name),
                        visited: $visited
                    )
                    .onTapGesture {
                        selectedTag = model
                        
                        if visited.contains(model.name) == false {
                            visited.append(model.name)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .animation(.linear(duration: 0.2), value: selectedTag.name)
        }
        .onAppear() {
            visited.append(selectedTag.name)
        }
    }
}

struct TagIconCapsule : View {
    let image: String
    let title: String
    @Binding var isSelected: String
    var isFirst: Bool = false
    
    @Binding var visited: [String]
    
    var body: some View {
        HStack(spacing: -1) {
            
            if isFirst == false {
                Rectangle()
                    .fill(visited.contains(title) ? .primary700 : .primary100)
                    .frame(width: 14, height: 12)   // in figma this rectrangles width is of 12, but due to the capsule shape it looks like the rectangle is not a part of capsule to due to that the width is increased to 14, 1 from leading and trailing and adjust with the spacing.
                    .zIndex(1)
            }
            
            HStack(spacing: 10) {
                Image(image)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(visited.contains(title) ? .grayScale10 : .primary500)
                    .frame(width: (isSelected == title) ? 18 : 24, height: (isSelected == title) ? 18 : 24)
                
                if isSelected == title {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .padding(.vertical,(isSelected == title) ? 11 : 8)
            .padding(.trailing, (isSelected == title) ? 16 : 20)
            .padding(.leading, (isSelected == title) ? 12 : 20)
            .background(visited.contains(title) ? .primary700 : .primary100, in: .capsule)
            .zIndex(10)
        }
        .foregroundStyle(visited.contains(title) ? Color.white : Color(hex: "#4A4A4A"))
    }
}

#Preview {
    CanvasTagBar()
}
