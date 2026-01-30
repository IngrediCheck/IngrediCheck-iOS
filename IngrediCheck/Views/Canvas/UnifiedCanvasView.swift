//
//  UnifiedCanvasView.swift
//  IngrediCheck
//
//  Unified canvas view that consolidates MainCanvasView and EditableCanvasView.
//  Supports both onboarding flow and editing mode through CanvasMode configuration.
//

import SwiftUI

struct UnifiedCanvasView: View {

    // MARK: - Configuration

    let mode: CanvasMode
    var targetSectionName: String? = nil
    var titleOverride: String? = nil
    var showBackButton: Bool = true
    var onDismiss: (() -> Void)? = nil

    // MARK: - Environment

    @EnvironmentObject private var store: Onboarding
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(WebService.self) private var webService
    @Environment(AppState.self) private var appState
    @Environment(FamilyStore.self) private var familyStore
    @Environment(FoodNotesStore.self) private var foodNotesStore

    // MARK: - Shared State

    @State private var cardScrollTarget: UUID? = nil
    @State private var tagBarScrollTarget: UUID? = nil
    @State private var isLoadingMemberPreferences: Bool = false
    @State private var didFinishInitialLoad: Bool = false

    // MARK: - Onboarding-specific State

    @State private var previousSectionIndex: Int = 0

    // MARK: - Editing-specific State

    @State private var selectedMemberId: UUID? = nil
    @State private var isTabBarExpanded: Bool = true
    @State private var scrollY: CGFloat = 0
    @State private var prevValue: CGFloat = 0
    @State private var maxScrollOffset: CGFloat = 0
    @State private var hasScrolledToTarget: Bool = false
    @State private var headroomCollapsed: Bool = false
    @State private var scrollToEditedSection: String? = nil

    // MARK: - Computed Properties

    private var shouldCenterLifestyleNutrition: Bool {
        guard let targetSectionName, !targetSectionName.isEmpty else { return false }
        let t = targetSectionName.lowercased().replacingOccurrences(of: " ", with: "")
        return t.contains("lifestyle") || t.contains("nutrition")
    }

    private var showFamilyIconsOnChips: Bool {
        switch mode {
        case .onboarding(let flow):
            return flow == .family || flow == .singleMember
        case .editing:
            return familyStore.family?.otherMembers.isEmpty == false
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent

            // Edit sheet overlay removed - RootContainerView handles it globally
            // This prevents double-sheet issue when UnifiedCanvasView is embedded in HomeView
        }
        .modifier(
            ConditionalBottomTabBar(
                isEnabled: mode.showTabBar && !coordinator.isEditSheetPresented,
                gradientColors: [
                    Color.pageBackground.opacity(0),
                    Color.pageBackground
                ]
            ) {
                TabBar(
                    isExpanded: $isTabBarExpanded,
                    onRecentScansTap: {
                        // Navigate to Recent Scans view
                        appState.navigationPath.append(HistoryRouteItem.recentScansAll)
                    },
                    onChatBotTap: mode == .editing ? {
                        // Open AI Bot with food_notes context when in editing mode (Food Notes screen)
                        coordinator.showAIBotSheetWithContext()
                    } : nil
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        )
        .background(Color.pageBackground)
        .navigationTitle(mode == .editing ? (titleOverride ?? "Food Notes") : "")
        .navigationBarTitleDisplayMode(.inline)
        // Sync indicator removed - using redacted loading for initial load only
        .onAppear {
            handleOnAppear()
        }
        .onDisappear {
            handleOnDisappear()
        }
        .task {
            await handleFoodNotesLoad()
        }
        .onChange(of: store.currentSectionIndex) { newIndex in
            handleSectionIndexChange(newIndex)
        }
        .onChange(of: store.preferences) { _ in
            handlePreferencesChange()
        }
        .onChange(of: familyStore.selectedMemberId) { newValue in
            handleMemberSwitch(newValue)
        }
        .onChange(of: coordinator.isEditSheetPresented) { oldValue, newValue in
            // When edit sheet is dismissed, scroll to the edited section and refresh canvas
            if oldValue == true && newValue == false, let stepId = coordinator.editingStepId {
                scrollToEditedSection = stepId
                // Force refresh of canvas cards to show updated selections (only in editing mode and after initial load)
                if mode == .editing && didFinishInitialLoad {
                    foodNotesStore.preparePreferencesForMember(selectedMemberId: selectedMemberId)
                }
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Top bar (mode-dependent)
            topBar
                .zIndex(10)

            // Tag bar (onboarding only)
            if mode.showTagBar {
                CanvasTagBar(
                    store: store,
                    onTapCurrentSection: {
                        scheduleScrollToCurrentSectionViews()
                    },
                    scrollTarget: $tagBarScrollTarget,
                    currentBottomSheetRoute: coordinator.currentBottomSheetRoute
                )
                .padding(.bottom, 16)
            }

            // Family member filter (editing only)
            if mode.showMemberFilter, let family = familyStore.family, !family.otherMembers.isEmpty {
                familyCapsulesRow(members: [family.selfMember] + family.otherMembers)
                    .padding(.top, 22)
                    .padding(.bottom, 16)
                    .padding(.horizontal, 16)
            }

            // Cards content
            cardsContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Top Bar

    @ViewBuilder
    private var topBar: some View {
        switch mode {
        case .onboarding:
            CustomIngrediCheckProgressBar(progress: CGFloat(store.progress * 100))
                .animation(.smooth, value: store.progress)
        case .editing:
            EmptyView() // Uses default navigation bar with title and back button
        }
    }

    // MARK: - Cards Content

    @ViewBuilder
    private var cardsContent: some View {
        let cards = buildCards()
        if mode.showTagBar {
            // Onboarding mode: use CanvasSummaryScrollView
            CanvasSummaryScrollView(
                cards: cards,
                scrollTarget: $cardScrollTarget,
                showPlaceholder: cards.isEmpty,
                itemMemberAssociations: foodNotesStore.itemMemberAssociations ?? [:],
                showFamilyIcons: showFamilyIconsOnChips
            )
        } else {
            // Editing mode: use custom scroll view with edit buttons
            // Data is already available from FoodNotesStore, refresh happens in background
            editableCardsScrollView(cards: cards)
        }
    }

    // MARK: - Build Cards (with sorting)

    private func buildCards() -> [CanvasCardModel] {
        return CanvasCardBuilder.buildCards(
            store: store,
            foodNotesStore: foodNotesStore,
            filterMemberId: mode == .editing ? selectedMemberId : nil,
            showAllSections: mode.showAllSections,
            sortBySelection: true
        )
    }

    // MARK: - Editable Cards Scroll View

    private func editableCardsScrollView(cards: [CanvasCardModel]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    // Show redacted loading skeleton only when store has no data yet (true initial load)
                    // Once store has data, never show redacted again (background refresh is silent)
                    let hasStoreData = foodNotesStore.hasLoadedFoodNotes
                    if !hasStoreData && !didFinishInitialLoad {
                        redactedLoadingContent
                    } else {
                        // AI Summary Card at top (only show if we have a summary and no member filter applied)
                        if selectedMemberId == nil,
                           let summary = foodNotesStore.foodNotesSummary,
                           !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           summary != "No Food Notes yet." {
                            AISummaryCard(
                                summary: summary,
                                dynamicSteps: store.dynamicSteps
                            )
                            .padding(.top, 16)
                        }

                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            EditableCanvasCard(
                                chips: card.chips,
                                sectionedChips: card.sectionedChips,
                                title: card.title,
                                iconName: card.icon,
                                onEdit: { openEdit(for: card) },
                                itemMemberAssociations: foodNotesStore.itemMemberAssociations ?? [:],
                                showFamilyIcons: showFamilyIconsOnChips,
                                activeMemberId: selectedMemberId
                            )
                            .padding(.top, index == 0 && foodNotesStore.foodNotesSummary == nil ? 16 : 0)
                            .id(card.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, coordinator.isEditSheetPresented ? UIScreen.main.bounds.height * 0.5 : 80)
                .background(scrollTrackingBackground)
            }
            .coordinateSpace(name: "editableCanvasScroll")
            .onAppear {
                scrollToTargetSectionIfNeeded(cards: cards, proxy: proxy)
            }
            .onChange(of: didFinishInitialLoad) { _ in
                scrollToTargetSectionIfNeeded(cards: cards, proxy: proxy)
            }
            .onChange(of: scrollToEditedSection) { _, stepId in
                guard let stepId = stepId else { return }
                // Find the card with matching stepId and scroll to it
                if let card = cards.first(where: { $0.stepId == stepId }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(card.id, anchor: .center)
                        }
                        scrollToEditedSection = nil
                    }
                }
            }
        }
    }

    // MARK: - Redacted Loading Content

    @ViewBuilder
    private var redactedLoadingContent: some View {
        VStack(spacing: 12) {
            // Skeleton AI Summary Card
            RedactedSummaryCard()
                .padding(.top, 16)

            // Skeleton Cards (show 4 placeholder cards)
            ForEach(0..<4, id: \.self) { _ in
                RedactedCanvasCard()
            }
        }
    }

    // MARK: - Family Capsules Row

    @ViewBuilder
    private func familyCapsulesRow(members: [FamilyMember]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(members, id: \.id) { member in
                    let isSelected = selectedMemberId == member.id

                    HStack(spacing: 8) {
                        MemberAvatar.custom(member: member, size: 24, imagePadding: 0)

                        Text(member.name)
                            .font(ManropeFont.medium.size(14))
                            .foregroundStyle(isSelected ? .white : .grayScale150)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 36, alignment: .leading)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color(hex: "#91B640") : Color(hex: "#F8F8F8"))
                    )
                    .onTapGesture {
                        // Toggle selection: tap again to deselect and show all
                        if selectedMemberId == member.id {
                            selectedMemberId = nil
                        } else {
                            selectedMemberId = member.id
                        }
                    }
                }
            }
        }
    }


    // MARK: - Scroll Tracking Background (Editing only)

    private var scrollTrackingBackground: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    scrollY = geo.frame(in: .named("editableCanvasScroll")).minY
                    prevValue = scrollY
                    maxScrollOffset = scrollY < 0 ? scrollY : 0
                }
                .onChange(of: geo.frame(in: .named("editableCanvasScroll")).minY) { newValue in
                    scrollY = newValue

                    if scrollY < 0 {
                        maxScrollOffset = min(maxScrollOffset, newValue)

                        let scrollDelta = newValue - prevValue
                        let minScrollDelta: CGFloat = 5

                        if scrollDelta < -minScrollDelta {
                            isTabBarExpanded = false
                        } else if scrollDelta > minScrollDelta {
                            let bottomThreshold: CGFloat = 100
                            if newValue > (maxScrollOffset + bottomThreshold) {
                                isTabBarExpanded = true
                            }
                        }
                    } else {
                        maxScrollOffset = 0
                    }

                    prevValue = newValue
                }
        }
    }

    // MARK: - Event Handlers

    private func handleOnAppear() {
        if case .onboarding(let flow) = mode {
            store.onboardingFlowtype = flow
        }
        store.updateSectionCompletionStatus()
        previousSectionIndex = store.currentSectionIndex
    }

    private func handleOnDisappear() {
        onDismiss?()
        if mode == .editing && coordinator.isEditSheetPresented {
            withAnimation(.easeInOut(duration: 0.2)) {
                coordinator.isEditSheetPresented = false
            }
        }
    }

    private func handleFoodNotesLoad() async {
        Log.debug("UnifiedCanvasView", "Food notes load task triggered")

        await foodNotesStore.loadFoodNotesAll()
        foodNotesStore.preparePreferencesForMember(selectedMemberId: familyStore.selectedMemberId)
        didFinishInitialLoad = true
    }

    private func handleSectionIndexChange(_ newIndex: Int) {
        previousSectionIndex = newIndex
        if mode.showTagBar {
            scheduleScrollToCurrentSectionViews()
            syncBottomSheetWithCurrentSection()
        }
    }

    private func handlePreferencesChange() {
        store.updateSectionCompletionStatus()

        if isLoadingMemberPreferences {
            Log.debug("UnifiedCanvasView", "Preferences updated during load, skipping save")
            return
        }

        guard !store.preferences.sections.isEmpty else {
            Log.debug("UnifiedCanvasView", "Skipping save - preferences are empty")
            return
        }

        let changedSectionName = store.currentSection.name
        Log.debug("UnifiedCanvasView", "Preferences changed, saving section \(changedSectionName)")

        Task {
            guard !isLoadingMemberPreferences, !store.preferences.sections.isEmpty else {
                return
            }

            foodNotesStore.applyLocalPreferencesOptimistic()
            foodNotesStore.updateFoodNotes()

            // Trigger scan history refresh when user navigates back to HomeView
            await MainActor.run {
                appState.needsScanHistoryRefresh = true
            }
        }
    }

    private func handleMemberSwitch(_ newValue: UUID?) {
        // Don't switch members before initial load completes - it would clear preferences
        guard didFinishInitialLoad else {
            Log.debug("UnifiedCanvasView", "Member switch ignored - initial load not complete")
            return
        }
        Log.debug("UnifiedCanvasView", "Member switched to \(newValue?.uuidString ?? "Everyone")")
        isLoadingMemberPreferences = true
        foodNotesStore.preparePreferencesForMember(selectedMemberId: newValue)
        isLoadingMemberPreferences = false
    }

    private func handleBackButton() {
        if coordinator.isEditSheetPresented {
            withAnimation(.easeInOut(duration: 0.2)) {
                coordinator.isEditSheetPresented = false
            }
        }
        dismiss()
    }

    // MARK: - Scroll Helpers (Onboarding)

    private func scheduleScrollToCurrentSectionViews() {
        let currentSectionId = store.currentSection.id
        cardScrollTarget = currentSectionId
        tagBarScrollTarget = currentSectionId
    }

    private func syncBottomSheetWithCurrentSection() {
        guard case .mainCanvas = coordinator.currentCanvasRoute else { return }
        guard let stepId = store.currentSection.screens.first?.stepId else { return }

        let targetRoute = BottomSheetRoute.onboardingStep(stepId: stepId)
        if targetRoute != coordinator.currentBottomSheetRoute {
            coordinator.navigateInBottomSheet(targetRoute)
        }
    }

    // MARK: - Scroll Helpers (Editing)

    private func scrollToTargetSectionIfNeeded(cards: [CanvasCardModel], proxy: ScrollViewProxy) {
        guard !hasScrolledToTarget else { return }
        guard let targetSectionName, !targetSectionName.isEmpty else { return }
        guard didFinishInitialLoad else { return }
        guard let targetCard = findTargetCard(cards: cards, targetSectionName: targetSectionName) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.45)) {
                let anchorPoint: UnitPoint = shouldCenterLifestyleNutrition ? .top : .center
                proxy.scrollTo(targetCard.id, anchor: anchorPoint)
            }
            hasScrolledToTarget = true
        }
    }

    private func findTargetCard(cards: [CanvasCardModel], targetSectionName: String) -> CanvasCardModel? {
        func norm(_ s: String) -> String {
            s.lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
        }

        let target = norm(targetSectionName)

        if let match = cards.first(where: { norm($0.title) == target }) {
            return match
        }

        if let nutrition = cards.first(where: { norm($0.title).contains("nutrition") }) {
            return nutrition
        }

        return nil
    }

    // MARK: - Edit Helpers (Editing)

    private func openEdit(for card: CanvasCardModel) {
        if let sectionIndex = store.sections.firstIndex(where: { section in
            section.screens.first?.stepId == card.stepId
        }) {
            coordinator.currentEditingSectionIndex = sectionIndex
            store.currentSectionIndex = sectionIndex
        }
        coordinator.editingStepId = card.stepId
        coordinator.editingMemberId = selectedMemberId  // Pass selected member to edit sheet
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            coordinator.isEditSheetPresented = true
        }
    }
}

// MARK: - Redacted Loading Components

private struct RedactedSummaryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header placeholder
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.grayScale40)
                    .frame(width: 100, height: 16)
                Spacer()
            }

            // Summary text placeholder lines
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.grayScale40)
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.grayScale40)
                    .frame(width: 200, height: 14)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .redacted(reason: .placeholder)
        .shimmering()
    }
}

private struct RedactedCanvasCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title row placeholder
            HStack {
                Circle()
                    .fill(Color.grayScale40)
                    .frame(width: 24, height: 24)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.grayScale40)
                    .frame(width: 120, height: 18)

                Spacer()

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.grayScale40)
                    .frame(width: 50, height: 28)
            }

            // Chips placeholder
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.grayScale40)
                        .frame(width: CGFloat.random(in: 60...100), height: 28)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .redacted(reason: .placeholder)
        .shimmering()
    }
}

// MARK: - Shimmer Effect
// ShimmerModifier is now in Utilities/ShimmerModifier.swift

// MARK: - Preview

//#Preview("Onboarding") {
//    let webService = WebService()
//    let onboarding = Onboarding(onboardingFlowtype: .individual)
//    let foodNotesStore = FoodNotesStore(webService: webService, onboardingStore: onboarding)
//
//    UnifiedCanvasView(mode: .onboarding(flow: .individual))
//        .environmentObject(onboarding)
//        .environment(webService)
//        .environment(foodNotesStore)
//}

//#Preview("Editing") {
//    let webService = WebService()
//    let onboarding = Onboarding(onboardingFlowtype: .individual)
//    let foodNotesStore = FoodNotesStore(webService: webService, onboardingStore: onboarding)
//
//    UnifiedCanvasView(mode: .editing)
//        .environmentObject(onboarding)
//        .environment(webService)
//        .environment(foodNotesStore)
//}

#Preview("Redacted Loading") {
    VStack(spacing: 16) {
        RedactedSummaryCard()
        RedactedCanvasCard()
        RedactedCanvasCard()
    }
    .padding()
    .background(Color.pageBackground)
}
