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
                    // Scroll to the current section’s cards when tapping the active tag
                    scheduleScrollToCurrentSectionViews()
                },
                scrollTarget: $tagBarScrollTarget
            )
            .padding(.bottom, 16)
            
            if let cards, cards.isEmpty == false {
                CanvasSummaryScrollView(
                    cards: cards,
                    scrollTarget: $cardScrollTarget
                )
//                .padding(.horizontal, 20)
            }
        }
		.onAppear {
            store.onboardingFlowtype = flow
		}
		.onChange(of: store.currentSectionIndex) { _ in
            scheduleScrollToCurrentSectionViews()
            syncBottomSheetWithCurrentSection()
		}
        .navigationBarBackButtonHidden(true)
    }
    
    private func icon(for screenId: OnboardingScreenId) -> String {
        switch screenId {
        case .allergies: return "allergies"
        case .intolerances: return "mingcute_alert-line"
        case .healthConditions: return "lucide_stethoscope"
        case .lifeStage: return "lucide_baby"
        case .region: return "nrk_globe"
        case .aviod: return "charm_circle-cross"
        case .lifeStyle: return "hugeicons_plant-01"
        case .nutrition: return "fluent-emoji-high-contrast_fork-and-knife-with-plate"
        case .ethical: return "streamline_recycle-1-solid"
        case .taste: return "iconoir_chocolate"
        }
    }
    
    private func scheduleScrollToCurrentSectionViews() {
        let currentSectionId = store.currentSection.id
        cardScrollTarget = currentSectionId
        tagBarScrollTarget = currentSectionId
    }
    
    /// Keep the bottom sheet question in sync with the currently selected section (tag).
    private func syncBottomSheetWithCurrentSection() {
        guard case .mainCanvas = coordinator.currentCanvasRoute else { return }
        guard let screenId = store.currentSection.screens.first?.screenId else { return }
        
        let targetRoute = bottomSheetRoute(for: screenId)
        if targetRoute != coordinator.currentBottomSheetRoute {
            coordinator.navigateInBottomSheet(targetRoute)
        }
    }
    
    private func chips(for screenId: OnboardingScreenId) -> [ChipsModel]? {
        let preferences = store.preferences
        switch screenId {
        case .allergies:
            return chipModels(from: preferences.allergies)
        case .intolerances:
            return chipModels(from: preferences.intolerances)
        case .healthConditions:
            return chipModels(from: preferences.healthConditions)
        case .lifeStage:
            return chipModels(from: preferences.lifeStage)
        case .ethical:
            return chipModels(from: preferences.ethical)
        case .taste:
            return chipModels(from: preferences.taste)
        default:
            return nil
        }
    }
    
    private func sectionedChips(for screenId: OnboardingScreenId) -> [SectionedChipModel]? {
        switch screenId {
        case .region:
            return regionSectionedChips()
        case .aviod:
            return avoidSectionedChips()
        case .lifeStyle:
            return lifestyleSectionedChips()
        case .nutrition:
            return nutritionSectionedChips()
        default:
            return nil
        }
    }
    
    private func canvasCards() -> [CanvasCardModel]? {
        var cards: [CanvasCardModel] = []
        
        for section in store.sections {
            guard let screenId = section.screens.first?.screenId else { continue }
            let chips = chips(for: screenId)
            let groupedChips = sectionedChips(for: screenId)
            
            if chips != nil || groupedChips != nil {
                cards.append(
                    CanvasCardModel(
                        id: section.id,
                        title: section.name,
                        icon: icon(for: screenId),
                        chips: chips,
                        sectionedChips: groupedChips
                    )
                )
            }
        }
        
        return cards.isEmpty ? nil : cards
    }
    
    private func chipModels(from list: [String]?) -> [ChipsModel]? {
        guard let items = list, !items.isEmpty else { return nil }
        return items.map { ChipsModel(name: $0, icon: nil) }
    }
    
    private func regionSectionedChips() -> [SectionedChipModel]? {
        guard let region = store.preferences.region else { return nil }
        let groups: [(String, [String])] = [
            ("India & South Asia", region.indiaSouthAsia),
            ("Africa", region.africa),
            ("East Asian", region.eastAsian),
            ("Middle East and Mediterranean", region.middleEastMediterranean),
            ("Western / Native traditions", region.westernNative),
            ("Seventh-day Adventist", region.seventhDayAdventist),
            ("Other", region.other)
        ]
        return sectionedModels(from: groups)
    }
    
    private func avoidSectionedChips() -> [SectionedChipModel]? {
        guard let avoid = store.preferences.avoid else { return nil }
        let groups: [(String, [String])] = [
            ("Oils & Fats", avoid.oilsFats),
            ("Animal Based", avoid.animalBased),
            ("Stimulants and Substances", avoid.stimulantsSubstances),
            ("Additives and Sweeteners", avoid.additivesSweeteners),
            ("Plant-Based Restrictions", avoid.plantBasedRestrictions)
        ]
        return sectionedModels(from: groups)
    }
    
    private func lifestyleSectionedChips() -> [SectionedChipModel]? {
        guard let lifestyle = store.preferences.lifestyle else { return nil }
        let groups: [(String, [String])] = [
            ("Plant & Balance", lifestyle.plantBalance),
            ("Quality & Source", lifestyle.qualitySource),
            ("Sustainable Living", lifestyle.sustainableLiving)
        ]
        return sectionedModels(from: groups)
    }
    
    private func nutritionSectionedChips() -> [SectionedChipModel]? {
        guard let nutrition = store.preferences.nutrition else { return nil }
        let groups: [(String, [String])] = [
            ("Macronutrient Goals", nutrition.macronutrientGoals),
            ("Sugar & Fiber", nutrition.sugarFiber),
            ("Diet Frameworks & Patterns", nutrition.dietFrameworks)
        ]
        return sectionedModels(from: groups)
    }
    
    private func sectionedModels(from groups: [(String, [String])]) -> [SectionedChipModel]? {
        let sections = groups.compactMap { title, items -> SectionedChipModel? in
            guard items.isEmpty == false else { return nil }
            let chips = items.map { ChipsModel(name: $0, icon: nil) }
            return SectionedChipModel(title: title, chips: chips)
        }
        return sections.isEmpty ? nil : sections
    }
    
    private func bottomSheetRoute(for screenId: OnboardingScreenId) -> BottomSheetRoute {
        switch screenId {
        case .allergies: return .allergies
        case .intolerances: return .intolerances
        case .healthConditions: return .healthConditions
        case .lifeStage: return .lifeStage
        case .region: return .region
        case .aviod: return .avoid
        case .lifeStyle: return .lifeStyle
        case .nutrition: return .nutrition
        case .ethical: return .ethical
        case .taste: return .taste
        }
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
    @State private var previousCardCount: Int = 0
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                // Add dynamic bottom padding so content can scroll above the sheet
                let extraBottomPadding: CGFloat = cards.count > 1
                    ? UIScreen.main.bounds.height * 1.0
                    : 20
                
                VStack(spacing: 16) {
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
}
