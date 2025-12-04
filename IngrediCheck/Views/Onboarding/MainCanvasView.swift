//
//  MainCanvasView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

struct MainCanvasView: View {
    
    @EnvironmentObject private var store: Onboarding
    @Environment(AppNavigationCoordinator.self) private var coordinator
    private let flow: OnboardingFlowType
    
    @State private var cardScrollTarget: UUID? = nil
    @State private var tagBarScrollTarget: UUID? = nil
	
	init(flow: OnboardingFlowType) {
        self.flow = flow
	}
    
    var body: some View {
        let cards = canvasCards()
        
        VStack(spacing: 0) {
            CustomIngrediCheckProgressBar(progress: CGFloat(store.progress * 100))
                .animation(.smooth, value: store.progress)
            
            CanvasTagBar(
                store: store,
                onTapCurrentSection: {
                    // Scroll to the current section's cards when tapping the active tag
                    scheduleScrollToCurrentSectionViews()
                },
                scrollTarget: $tagBarScrollTarget,
                currentBottomSheetRoute: coordinator.currentBottomSheetRoute
            )
            .padding(.bottom, 16)
            
            // Always show the scroll view, and let it decide whether to render
            // real cards or a placeholder when there is no data.
            CanvasSummaryScrollView(
                cards: cards ?? [],
                scrollTarget: $cardScrollTarget,
                showPlaceholder: cards?.isEmpty ?? true
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
		.onAppear {
            store.onboardingFlowtype = flow
		}
		.onChange(of: store.currentSectionIndex) { _ in
            scheduleScrollToCurrentSectionViews()
            syncBottomSheetWithCurrentSection()
		}
        .navigationBarBackButtonHidden(true)
    }
    
    private func icon(for stepId: String) -> String {
        // Get icon from dynamic JSON
        if let step = store.step(for: stepId),
           let icon = step.header.iconURL,
           icon.isEmpty == false {
            return icon
        }
        // Fallback to default icon if not found
        return "allergies"
    }
    
    private func scheduleScrollToCurrentSectionViews() {
        let currentSectionId = store.currentSection.id
        cardScrollTarget = currentSectionId
        tagBarScrollTarget = currentSectionId
    }
    
    /// Keep the bottom sheet question in sync with the currently selected section (tag).
    private func syncBottomSheetWithCurrentSection() {
        guard case .mainCanvas = coordinator.currentCanvasRoute else { return }
        guard let stepId = store.currentSection.screens.first?.stepId else { return }
        
        let targetRoute = BottomSheetRoute.onboardingStep(stepId: stepId)
        if targetRoute != coordinator.currentBottomSheetRoute {
            coordinator.navigateInBottomSheet(targetRoute)
        }
    }
    
    private func chips(for stepId: String) -> [ChipsModel]? {
        guard let step = store.step(for: stepId) else { return nil }
        let sectionName = step.header.name
        
        guard let value = store.preferences.sections[sectionName],
              case .list(let items) = value else {
            return nil
        }
        
        return chipModels(from: items)
    }
    
    private func sectionedChips(for stepId: String) -> [SectionedChipModel]? {
        guard let step = store.step(for: stepId) else { return nil }
        let sectionName = step.header.name
        
        guard let value = store.preferences.sections[sectionName],
              case .nested(let nestedDict) = value else {
            return nil
        }
        
        // Convert nested dict to sectioned chips
        let groups: [(String, [String])] = nestedDict.map { (key, value) in
            (key, value)
        }
        
        return sectionedModels(from: groups)
    }
    
    private func canvasCards() -> [CanvasCardModel]? {
        var cards: [CanvasCardModel] = []
        
        for section in store.sections {
            guard let stepId = section.screens.first?.stepId else { continue }
            let chips = chips(for: stepId)
            let groupedChips = sectionedChips(for: stepId)
            
            if chips != nil || groupedChips != nil {
                cards.append(
                    CanvasCardModel(
                        id: section.id,
                        title: section.name,
                        icon: icon(for: stepId),
                        chips: chips,
                        sectionedChips: groupedChips
                    )
                )
            }
        }
        
        return cards.isEmpty ? nil : cards
    }
    
    private func chipModels(from list: [String]) -> [ChipsModel]? {
        guard !list.isEmpty else { return nil }
        return list.map { ChipsModel(name: $0, icon: nil) }
    }
    
    private func sectionedModels(from groups: [(String, [String])]) -> [SectionedChipModel]? {
        let sections = groups.compactMap { title, items -> SectionedChipModel? in
            guard items.isEmpty == false else { return nil }
            let chips = items.map { ChipsModel(name: $0, icon: nil) }
            return SectionedChipModel(title: title, chips: chips)
        }
        return sections.isEmpty ? nil : sections
    }
    
}

struct CanvasCardModel: Identifiable {
    let id: UUID
    let title: String
    let icon: String
    let chips: [ChipsModel]?
    let sectionedChips: [SectionedChipModel]?
}

struct CanvasSummaryScrollView: View {
    let cards: [CanvasCardModel]
    @Binding var scrollTarget: UUID?
    let showPlaceholder: Bool
    @State private var previousCardCount: Int = 0
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                // Add dynamic bottom padding so content can scroll above the sheet
                let extraBottomPadding: CGFloat = (!showPlaceholder && cards.count > 1)
                    ? UIScreen.main.bounds.height * 1.0
                    : 20
                
                VStack(spacing: 16) {
                    if showPlaceholder {
                        // Empty-state placeholder when there are no cards yet:
                        // show a stack of dummy cards similar to the real layout.
                        ForEach(0..<5, id: \.self) { index in
                            SkeletonCanvasCard()
                                .padding(.top, index == 0 ? 16 : 0)
                        }
                    } else {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            CanvasCard(
                                chips: card.chips,
                                sectionedChips: card.sectionedChips,
                                title: card.title,
                                iconName: card.icon
                            )
                            .id(card.id)
                            // Add visual gap from the top edge so the card
                            // never touches the top when scrolled into view.
                            .padding(.top, index == 0 ? 16 : 0)
                        }
                    }
                }
                .padding(.horizontal, 16)
                // Extra bottom padding so the last items can scroll fully above the bottom sheet,
                // but only once there is more than one card to avoid an initial jump.
                .padding(.bottom, extraBottomPadding)
            }
            .onAppear {
                previousCardCount = cards.count
            }
            .onChange(of: cards.map(\.id)) { _ in
                handleCardsChange(proxy: proxy)
            }
            .onChange(of: scrollTarget) { _ in
                handleScrollTarget(proxy: proxy)
            }
        }
    }
    
    private func handleCardsChange(proxy: ScrollViewProxy) {
        // When a new card is added (e.g. user picks chips in a new section),
        // automatically scroll so that the newest card is brought to the top.
        if cards.count > previousCardCount,
           let lastId = cards.last?.id {
            scrollTo(id: lastId, proxy: proxy)
        }
        previousCardCount = cards.count
    }
    
    private func handleScrollTarget(proxy: ScrollViewProxy) {
        guard let target = scrollTarget,
              cards.contains(where: { $0.id == target }) else { return }
        
        scrollTo(id: target, proxy: proxy)
        scrollTarget = nil
    }
    
    private func scrollTo(id: UUID, proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }
}

/// Lightweight skeleton version of the canvas card, used as a placeholder
/// when there is no data yet. Designed to roughly match the card layout
/// without showing any real content.
struct SkeletonCanvasCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.grayScale10)
            
            VStack(alignment: .leading, spacing: 12) {
                // Title bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.grayScale30)
                    .frame(width: UIScreen.main.bounds.width * 0.46, height: UIScreen.main.bounds.height * 0.02)
                
                // Three rows of pill placeholders
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 8) {
                            Capsule()
                                .fill(Color.grayScale30)
                                .frame(width: CGFloat(Int.random(in: 100...150)), height: UIScreen.main.bounds.height * 0.04)
                            
                            Capsule()
                                .fill(Color.grayScale30)
                                .frame(width: CGFloat(Int.random(in: 100...150)), height: UIScreen.main.bounds.height * 0.04)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.22)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.grayScale60, lineWidth: 0.25)
        )
    }
}

func onboardingSheetTitle(title: String) -> some View {
    Group {
        (Text("Q. ")
            .font(ManropeFont.bold.size(20))
            .foregroundStyle(.grayScale70)
        +
        Text(title)
            .font(NunitoFont.bold.size(20))
            .foregroundStyle(.grayScale150))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true) // <-- important
    }
    
}

func onboardingSheetSubtitle(subtitle: String, onboardingFlowType: OnboardingFlowType) -> some View {
    if onboardingFlowType == .individual {
        Text(subtitle)
            .font(ManropeFont.regular.size(14))
            .foregroundStyle(.grayScale100)
            .fixedSize(horizontal: false, vertical: true) // <-- important
    } else {
        Text(subtitle)
            .font(ManropeFont.regular.size(14))
            .foregroundStyle(.grayScale120)
            .fixedSize(horizontal: false, vertical: true) // <-- important
    }
}

func onboardingSheetFamilyMemberSelectNote() -> some View {
    HStack(alignment: .center, spacing: 0) {
        
        Image(.yellowBulb)
            .resizable()
            .frame(width: 22, height: 26)
        
        Text("Select members one by one to personalize their choices.")
            .font(ManropeFont.regular.size(12))
            .foregroundStyle(.grayScale100)
    }
}

#Preview {
    MainCanvasView(flow: .individual)
        .environmentObject(Onboarding(onboardingFlowtype: .individual))
    
    
//    ZStack {
//        Color.gray
//        VStack {
//            SkeletonCanvasCard()
//            SkeletonCanvasCard()
//            SkeletonCanvasCard()
//            SkeletonCanvasCard()
//        }
//        
//    }
}
