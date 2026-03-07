//
//  MainCanvasView.swift
//  IngrediCheck
//
//  Legacy wrapper retained for compatibility.
//

import SwiftUI

struct MainCanvasView: View {
    private let flow: OnboardingFlowType

    init(flow: OnboardingFlowType) {
        self.flow = flow
    }

    var body: some View {
        UnifiedCanvasView(mode: .onboarding(flow: flow))
    }
}

struct CanvasCardModel: Identifiable {
    let id: UUID
    let title: String
    let icon: String
    let stepId: String
    let chips: [ChipsModel]?
    let sectionedChips: [SectionedChipModel]?
}

struct CanvasSummaryScrollView: View {
    let cards: [CanvasCardModel]
    @Binding var scrollTarget: UUID?
    let showPlaceholder: Bool
    let itemMemberAssociations: [String: [String: [String]]]
    let showFamilyIcons: Bool
    @State private var previousCardCount: Int = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                let extraBottomPadding: CGFloat = (!showPlaceholder && cards.count > 1)
                    ? UIScreen.main.bounds.height * 1.0
                    : 20

                VStack(spacing: 16) {
                    if showPlaceholder {
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
                                iconName: card.icon,
                                itemMemberAssociations: itemMemberAssociations,
                                showFamilyIcons: showFamilyIcons
                            )
                            .id(card.id)
                            .padding(.top, index == 0 ? 16 : 0)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, extraBottomPadding)
            }
            .onAppear {
                previousCardCount = cards.count
            }
            .onChange(of: cards.map(\.id)) {
                handleCardsChange(proxy: proxy)
            }
            .onChange(of: scrollTarget) {
                handleScrollTarget(proxy: proxy)
            }
        }
    }

    private func handleCardsChange(proxy: ScrollViewProxy) {
        if cards.count > previousCardCount, let lastId = cards.last?.id {
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

struct SkeletonCanvasCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.grayScale10)

            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.grayScale30)
                    .frame(width: UIScreen.main.bounds.width * 0.46, height: UIScreen.main.bounds.height * 0.02)

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
        .fixedSize(horizontal: false, vertical: true)
    }
}

func onboardingSheetTitle(template: String, memberName: String, memberColor: Color) -> some View {
    let parts = template.components(separatedBy: "{name}")
    return Group {
        (Text("Q. ")
            .font(ManropeFont.bold.size(20))
            .foregroundStyle(.grayScale70)
        +
        Text(parts.first ?? "")
            .font(NunitoFont.bold.size(20))
            .foregroundStyle(.grayScale150)
        +
        Text(memberName)
            .font(NunitoFont.bold.size(20))
            .foregroundStyle(memberColor)
        +
        Text(parts.count > 1 ? parts[1] : "")
            .font(NunitoFont.bold.size(20))
            .foregroundStyle(.grayScale150))
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

func onboardingSheetSubtitle(subtitle: String, onboardingFlowType: OnboardingFlowType) -> some View {
    if onboardingFlowType == .individual {
        Text(subtitle)
            .font(ManropeFont.regular.size(14))
            .foregroundStyle(.grayScale100)
            .fixedSize(horizontal: false, vertical: true)
    } else {
        Text(subtitle)
            .font(ManropeFont.regular.size(14))
            .foregroundStyle(.grayScale120)
            .fixedSize(horizontal: false, vertical: true)
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
    let webService = WebService()
    let onboarding = Onboarding(onboardingFlowtype: .individual)
    let foodNotesStore = FoodNotesStore(webService: webService, onboardingStore: onboarding)

    MainCanvasView(flow: .individual)
        .environmentObject(onboarding)
        .environment(webService)
        .environment(foodNotesStore)
}
