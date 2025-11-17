//
//  CanvasTagBar.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 03/10/25.
//

import SwiftUI

struct CanvasTagBar: View {
    
    @ObservedObject var store: Onboarding
    var onTapCurrentSection: (() -> Void)? = nil
    
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
    @State var visited: [String] = []
    
    private var selectedTitleBinding: Binding<String> {
        Binding(
            get: { store.sections[store.currentSectionIndex].name },
            set: { newName in
                guard let tappedIndex = iconsArr.firstIndex(where: { $0.name == newName }),
                      store.sections.indices.contains(tappedIndex) else { return }
                
                if tappedIndex == store.currentSectionIndex {
                    onTapCurrentSection?()
                    return
                }
                
                // Allow navigation to:
                // 1) any section that is marked complete, or
                // 2) any section that was already visited in this session
                if store.sections[tappedIndex].isComplete || visited.contains(store.sections[tappedIndex].name) {
                    store.currentSectionIndex = tappedIndex
                    store.currentScreenIndex = 0
                    if visited.contains(store.sections[tappedIndex].name) == false {
                        visited.append(store.sections[tappedIndex].name)
                    }
                }
            }
        )
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -1) {
                ForEach(iconsArr) { model in
                    TagIconCapsule(
                        image: model.icon ?? "",
                        title: model.name,
                        isSelected: selectedTitleBinding,
                        isFirst: (model.name == iconsArr.first?.name),
                        visited: $visited
                    )
                    .onTapGesture {
                        guard let tappedIndex = iconsArr.firstIndex(where: { $0.id == model.id }) else { return }
                        
                        guard store.sections.indices.contains(tappedIndex) else { return }
                        
                        if tappedIndex == store.currentSectionIndex {
                            onTapCurrentSection?()
                            return
                        }
                        
                        // Allow navigation to:
                        // 1) any section that is marked complete, or
                        // 2) any section that was already visited in this session
                        let tappedName = store.sections[tappedIndex].name
                        if store.sections[tappedIndex].isComplete || visited.contains(tappedName) {
                            store.currentSectionIndex = tappedIndex
                            store.currentScreenIndex = 0
                            if visited.contains(tappedName) == false {
                                visited.append(tappedName)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .animation(.linear(duration: 0.2), value: store.currentSectionIndex)
        }
        .onAppear() {
            // Initialize visited based on completed sections and current
            let completed = store.sections.filter { $0.isComplete }.map { $0.name }
            let current = store.sections[store.currentSectionIndex].name
            let initial = Array(Set(completed + [current]))
            visited = initial
        }
        .onReceive(store.$sections) { _ in
            // Refresh visited whenever completion state changes
            let completed = store.sections.filter { $0.isComplete }.map { $0.name }
            let current = store.sections[store.currentSectionIndex].name
            let updated = Array(Set(completed + [current]))
            visited = updated
        }
        .onChange(of: store.currentSectionIndex) { _ in
            let current = store.sections[store.currentSectionIndex].name
            if visited.contains(current) == false {
                visited.append(current)
            }
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

//#Preview {
//    CanvasTagBar()
//}
