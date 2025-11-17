//
//  MainCanvasView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

extension OnboardingScreenId: Identifiable {
	var id: String { rawValue }
}

struct MainCanvasView: View {
    
	@StateObject private var store: Onboarding
	@State private var presentedOnboardingSheet: OnboardingScreenId? = nil
    
    @State var preferences: Preferences = Preferences()
	
	init(flow: OnboardingFlowType) {
		_store = StateObject(wrappedValue: Onboarding(onboardingFlowtype: flow))
	}
    
    @State var goToHomeScreen: Bool = false
    
    var body: some View {
        ZStack {
            
            CustomSheet(item: $presentedOnboardingSheet,
                        cornerRadius: 34) { _ in
                VStack(spacing: 0) {
                    store.currentScreen.buildView(store.onboardingFlowtype, $preferences)
                        .padding(.bottom, 32)
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            if store.currentScreen.screenId.rawValue == "taste" {
                                presentedOnboardingSheet = nil
                                goToHomeScreen = true
                            } else {
                                store.next()
                            }
                        }, label: {
                            GreenCircle()
                        })
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .padding(.top, 8)
            }
            
            VStack(spacing: 0) {
                CustomIngrediCheckProgressBar(progress: CGFloat(store.progress * 100))
                    .animation(.smooth, value: store.progress)
                
                CanvasTagBar(store: store, onTapCurrentSection: {
                    // Re-present the current sheet when tapping the active tag
                    presentedOnboardingSheet = store.currentScreen.screenId
                })
                    .padding(.bottom, 16)
                
                
                RoundedRectangle(cornerRadius: 24)
                    .foregroundStyle(.white)
                    .shadow(color: .gray.opacity(0.3), radius: 9, x: 0, y: 0)
                    .frame(width: UIScreen.main.bounds.width * 0.9)
                    .overlay(alignment: .top) {
                        if let cards = canvasCards(), cards.isEmpty == false {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 16) {
                                    ForEach(cards, id: \.id) { card in
                                        CanvasCard(
                                            chips: card.chips,
                                            sectionedChips: card.sectionedChips,
                                            title: card.title,
                                            iconName: card.icon
                                        )
                                    }
                                }
                                .padding(.vertical, 20)
                                .padding(.horizontal, 16)
                            }
                            .frame(width: UIScreen.main.bounds.width * 0.9)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                    }
                
                
                NavigationLink(isActive: $goToHomeScreen) {
                    HomeView()
                } label: {
                    EmptyView()
                }

            }
            
        }
		.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                presentedOnboardingSheet = store.currentScreen.screenId
            }
		}
		.onChange(of: store.currentScreenIndex) { _ in
			presentedOnboardingSheet = store.currentScreen.screenId
		}
		.onChange(of: store.currentSectionIndex) { _ in
			presentedOnboardingSheet = store.currentScreen.screenId
		}
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
    
    private func chips(for screenId: OnboardingScreenId) -> [ChipsModel]? {
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
        guard let region = preferences.region else { return nil }
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
        guard let avoid = preferences.avoid else { return nil }
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
        guard let lifestyle = preferences.lifestyle else { return nil }
        let groups: [(String, [String])] = [
            ("Plant & Balance", lifestyle.plantBalance),
            ("Quality & Source", lifestyle.qualitySource),
            ("Sustainable Living", lifestyle.sustainableLiving)
        ]
        return sectionedModels(from: groups)
    }
    
    private func nutritionSectionedChips() -> [SectionedChipModel]? {
        guard let nutrition = preferences.nutrition else { return nil }
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
}

struct CanvasCardModel: Identifiable {
    let id: UUID
    let title: String
    let icon: String
    let chips: [ChipsModel]?
    let sectionedChips: [SectionedChipModel]?
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
}
