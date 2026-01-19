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
    @Environment(FamilyStore.self) private var familyStore
    @Environment(FoodNotesStore.self) private var foodNotesStore: FoodNotesStore?

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
            return flow == .family
        case .editing:
            return familyStore.family?.otherMembers.isEmpty == false
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent

            // Edit sheet overlay (editing mode only, for fullScreenCover presentation)
            if mode == .editing {
                editSheetOverlay
            }
        }
        .overlay(alignment: .bottom) {
            if mode.showTabBar {
                bottomGradientOverlay
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if mode.showTabBar {
                tabBarOverlay
            }
        }
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            handleOnAppear()
        }
        .onDisappear {
            handleOnDisappear()
        }
        .task(id: foodNotesStore != nil) {
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
            // When edit sheet is dismissed, scroll to the edited section
            if oldValue == true && newValue == false, let stepId = coordinator.editingStepId {
                scrollToEditedSection = stepId
            }
        }
    }

    // MARK: - Edit Sheet Overlay (for fullScreenCover presentation)

    @ViewBuilder
    private var editSheetOverlay: some View {
        if coordinator.isEditSheetPresented, let stepId = coordinator.editingStepId {
            EditSectionBottomSheet(
                isPresented: Binding(
                    get: { coordinator.isEditSheetPresented },
                    set: { coordinator.isEditSheetPresented = $0 }
                ),
                stepId: stepId,
                currentSectionIndex: coordinator.currentEditingSectionIndex
            )
            .transition(AnyTransition.asymmetric(
                insertion: AnyTransition.move(edge: Edge.bottom).combined(with: AnyTransition.opacity),
                removal: AnyTransition.move(edge: Edge.bottom).combined(with: AnyTransition.opacity)
            ))
            .zIndex(100)
            .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity, alignment: Alignment.bottom)
            .ignoresSafeArea()
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
            customNavigationBar
        }
    }

    @ViewBuilder
    private var customNavigationBar: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    if showBackButton {
                        Button {
                            handleBackButton()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                    }
                    Spacer()
                }

                Text(titleOverride ?? "Food Notes")
                    .font(NunitoFont.bold.size(18))
                    .foregroundStyle(.grayScale150)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(Color.white)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Cards Content

    @ViewBuilder
    private var cardsContent: some View {
        if foodNotesStore?.isLoadingFoodNotes == true && mode == .editing {
            loadingView
        } else {
            let cards = buildCards()
            if mode.showTagBar {
                // Onboarding mode: use CanvasSummaryScrollView
                CanvasSummaryScrollView(
                    cards: cards,
                    scrollTarget: $cardScrollTarget,
                    showPlaceholder: cards.isEmpty,
                    itemMemberAssociations: foodNotesStore?.itemMemberAssociations ?? [:],
                    showFamilyIcons: showFamilyIconsOnChips
                )
            } else {
                // Editing mode: use custom scroll view with edit buttons
                editableCardsScrollView(cards: cards)
            }
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
                    // AI Summary Card at top (only show if we have a summary)
                    if let summary = foodNotesStore?.foodNotesSummary,
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
                            itemMemberAssociations: foodNotesStore?.itemMemberAssociations ?? [:],
                            showFamilyIcons: showFamilyIconsOnChips,
                            activeMemberId: selectedMemberId
                        )
                        .padding(.top, index == 0 && foodNotesStore?.foodNotesSummary == nil ? 16 : 0)
                        .id(card.id)
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

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            Text("Loading your preferences...")
                .font(ManropeFont.medium.size(16))
                .foregroundStyle(.grayScale100)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Gradient Overlay (Editing only)

    @ViewBuilder
    private var bottomGradientOverlay: some View {
        if !coordinator.isEditSheetPresented {
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 132)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Tab Bar Overlay (Editing only)

    @ViewBuilder
    private var tabBarOverlay: some View {
        if !coordinator.isEditSheetPresented {
            TabBar(isExpanded: $isTabBarExpanded)
                .fixedSize(horizontal: false, vertical: true)
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
        guard foodNotesStore != nil else { return }
        Log.debug("UnifiedCanvasView", "Food notes load task triggered")

        await foodNotesStore?.loadFoodNotesAll()
        foodNotesStore?.preparePreferencesForMember(selectedMemberId: familyStore.selectedMemberId)
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

            foodNotesStore?.applyLocalPreferencesOptimistic()
            foodNotesStore?.updateFoodNotes()
        }
    }

    private func handleMemberSwitch(_ newValue: UUID?) {
        Log.debug("UnifiedCanvasView", "Member switched to \(newValue?.uuidString ?? "Everyone")")
        isLoadingMemberPreferences = true
        foodNotesStore?.preparePreferencesForMember(selectedMemberId: newValue)
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            coordinator.isEditSheetPresented = true
        }
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    let webService = WebService()
    let onboarding = Onboarding(onboardingFlowtype: .individual)
    let foodNotesStore = FoodNotesStore(webService: webService, onboardingStore: onboarding)

    UnifiedCanvasView(mode: .onboarding(flow: .individual))
        .environmentObject(onboarding)
        .environment(webService)
        .environment(foodNotesStore)
}

#Preview("Editing") {
    let webService = WebService()
    let onboarding = Onboarding(onboardingFlowtype: .individual)
    let foodNotesStore = FoodNotesStore(webService: webService, onboardingStore: onboarding)

    UnifiedCanvasView(mode: .editing)
        .environmentObject(onboarding)
        .environment(webService)
        .environment(foodNotesStore)
}
