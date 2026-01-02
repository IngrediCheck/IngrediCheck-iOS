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
    var currentBottomSheetRoute: BottomSheetRoute? = nil
    var allowTappingIncompleteSections: Bool = false // Allow tapping even if section is not completed (for EditableCanvasView)
    var forceDarkGreen: Bool = false

    /// Derived tag items from the dynamic sections / JSON, so that ordering,
    /// titles and icons always match the config.
    private var tagItems: [ChipsModel] {
        store.sections.compactMap { section in
            guard let stepId = section.screens.first?.stepId else { return nil }
            
            let iconName: String
            if let step = store.step(for: stepId),
               let icon = step.header.iconURL,
               icon.isEmpty == false {
                iconName = icon
            } else {
                // Fallback to a default icon if not found in JSON
                iconName = "allergies"  // Default fallback
            }
            
            return ChipsModel(name: section.name, icon: iconName)
        }
    }
    @State var visited: [String] = []
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -1) {
                    ForEach(Array(tagItems.enumerated()), id: \.offset) { index, model in
                        TagIconCapsule(
                            image: model.icon ?? "",
                            title: model.name,
                            isSelected: Binding(
                                get: { 
                                    // If fineTuneYourExperience is shown, return empty string so nothing is selected
                                    if case .fineTuneYourExperience = currentBottomSheetRoute {
                                        return ""
                                    }
                                    return store.sections[store.currentSectionIndex].name
                                },
                                set: { newName in
                                    handleSelection(newName: newName, proxy: proxy)
                                }
                            ),
                            isFirst: (index == 0),
                            visited: $visited,
                            forceDarkGreen: forceDarkGreen
                        )
                        .id(store.sections[safe: index]?.id)
                        .onTapGesture {
                            handleTap(index: index, proxy: proxy)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .animation(.linear(duration: 0.2), value: store.currentSectionIndex)
                .animation(.linear(duration: 0.2), value: currentBottomSheetRoute)
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
            // Initialize visited with sections up to and including current
            if store.sections.indices.contains(store.currentSectionIndex) {
                let currentIndex = store.currentSectionIndex
                let initial = store.sections.prefix(currentIndex + 1).map { $0.name }
                visited = Array(initial)
            }
        }
        .onChange(of: store.currentSectionIndex) { _, newIndex in
            // When user goes to a next section (or any section), mark it as visited
            // so it turns dark green immediately.
            if store.sections.indices.contains(newIndex) {
                let currentName = store.sections[newIndex].name
                if !visited.contains(currentName) {
                    visited.append(currentName)
                }
            }
        }
    }
    
    private func handleSelection(newName: String, proxy: ScrollViewProxy) {
        guard let tappedIndex = store.sections.firstIndex(where: { $0.name == newName }),
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
        // Allow tapping if: section is complete, has been visited, or if we're in edit mode (EditableCanvasView)
        if allowTappingIncompleteSections || store.sections[index].isComplete || visited.contains(tappedName) {
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
    var forceDarkGreen: Bool = false
    
    var body: some View {
        HStack(spacing: -1) {
            
            if isFirst == false {
                Rectangle()
                    .fill((forceDarkGreen || visited.contains(title)) ? .primary700 : .primary100)
                    .frame(width: 14, height: 12)   // in figma this rectrangles width is of 12, but due to the capsule shape it looks like the rectangle is not a part of capsule to due to that the width is increased to 14, 1 from leading and trailing and adjust with the spacing.
                    .zIndex(1)
            }
            
            HStack(spacing: 10) {
                Image(image)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle((forceDarkGreen || visited.contains(title)) ? .grayScale10 : .primary500)
                    .frame(width: (isSelected == title) ? 18 : 24, height: (isSelected == title) ? 18 : 24)
                
                if isSelected == title {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .padding(.vertical,(isSelected == title) ? 11 : 8)
            .padding(.trailing, (isSelected == title) ? 16 : 20)
            .padding(.leading, (isSelected == title) ? 12 : 20)
            .background((forceDarkGreen || visited.contains(title)) ? .primary700 : .primary100, in: .capsule)
            .zIndex(10)
        }
        .foregroundStyle((forceDarkGreen || visited.contains(title)) ? Color.white : Color(hex: "#4A4A4A"))
    }
}

//#Preview {
//    CanvasTagBar()
//}
