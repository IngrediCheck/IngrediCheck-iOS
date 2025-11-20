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
    @Binding var scrollTarget: UUID?
    
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
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -1) {
                    ForEach(iconsArr.indices, id: \.self) { index in
                        let model = iconsArr[index]
                        TagIconCapsule(
                            image: model.icon ?? "",
                            title: model.name,
                            isSelected: Binding(
                                get: { store.sections[store.currentSectionIndex].name },
                                set: { newName in
                                    handleSelection(newName: newName, proxy: proxy)
                                }
                            ),
                            isFirst: (model.name == iconsArr.first?.name),
                            visited: $visited
                        )
                        .id(store.sections[safe: index]?.id)
                        .onTapGesture {
                            handleTap(index: index, proxy: proxy)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .animation(.linear(duration: 0.2), value: store.currentSectionIndex)
            }
            .onChange(of: scrollTarget) { _ in
                guard let target = scrollTarget else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(target, anchor: .center)
                }
                scrollTarget = nil
            }
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
    
    private func handleSelection(newName: String, proxy: ScrollViewProxy) {
        guard let tappedIndex = iconsArr.firstIndex(where: { $0.name == newName }),
              store.sections.indices.contains(tappedIndex) else { return }
        
        handleSelection(at: tappedIndex, proxy: proxy)
    }
    
    private func handleTap(index: Int, proxy: ScrollViewProxy) {
        handleSelection(at: index, proxy: proxy)
    }
    
    private func handleSelection(at index: Int, proxy: ScrollViewProxy) {
        guard store.sections.indices.contains(index) else { return }
        
        if index == store.currentSectionIndex {
            onTapCurrentSection?()
            return
        }
        
        let tappedName = store.sections[index].name
        if store.sections[index].isComplete || visited.contains(tappedName) {
            store.currentSectionIndex = index
            store.currentScreenIndex = 0
            if visited.contains(tappedName) == false {
                visited.append(tappedName)
            }
            if let id = store.sections[index].id as UUID? {
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
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
                    .aspectRatio(contentMode: .fit)
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
