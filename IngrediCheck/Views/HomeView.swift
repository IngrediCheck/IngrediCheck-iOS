
//
//  HomeView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar on 10/11/25.
//

import SwiftUI
import AVFoundation

struct HomeView: View {
    @State private var isSettingsPresented = false
    @State private var isTabBarExpanded: Bool = true
    @State private var isRefreshingHistory: Bool = false
    @State private var showEditableCanvas: Bool = false
    @State private var editTargetSectionName: String? = nil
    @SceneStorage("didPlayAverageScansLaunchAnimation") private var didPlayAverageScansLaunchAnimation: Bool = false

    private final class ScrollTrackingState {
        var prevValue: CGFloat = 0
        var maxScrollOffset: CGFloat = 0
        var didInitialize: Bool = false
        var scrollEndWorkItem: DispatchWorkItem?
    }

    @State private var scrollTrackingState = ScrollTrackingState()
    @State private var stats: DTO.StatsResponse? = nil
    @State private var isLoadingStats: Bool = false
    @State private var hasCheckedAutoScan: Bool = false
    @State private var didFinishInitialLoad: Bool = false
    // ---------------------------
    // MERGED FROM YOUR BRANCH
    // ---------------------------
    private struct ProductDetailPayload: Identifiable {
        let id = UUID()
        let scanId: String  // scan.id for ProductDetailView to track
        let scan: DTO.Scan  // Full scan object to pass as initialScan
        let product: DTO.Product
        let matchStatus: DTO.ProductRecommendation
        let ingredientRecommendations: [DTO.IngredientRecommendation]?
        let clientActivityId: String?  // Optional for backwards compatibility (legacy API)
        let favorited: Bool
    }
    
    
    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService
    @Environment(ScanHistoryStore.self) var scanHistoryStore
    @Environment(UserPreferences.self) var userPreferences
    @Environment(AuthController.self) private var authController
    @Environment(FoodNotesStore.self) private var foodNotesStore
    @EnvironmentObject private var onboarding: Onboarding
    // ---------------------------
    // MERGED FROM DEVELOP BRANCH
    // ---------------------------
    @Environment(FamilyStore.self) private var familyStore
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(MemojiStore.self) private var memojiStore
    private var familyMembers: [FamilyMember] {
        guard let family = familyStore.family else { return [] }
        return [family.selfMember] + family.otherMembers
    }
    private var primaryMemberName: String {
        return familyStore.family?.selfMember.name ?? "BiteBuddy"
    }
    
    // MARK: - Family avatars
    
    /// Small avatar used under "Your IngrediFam". Shows the member's memoji
    /// if an imageFileHash is present, otherwise falls back to the first
    /// letter of their name on top of their color.
    struct FamilyMemberAvatarView: View {
        let member: FamilyMember
        
        var body: some View {
            // Use centralized MemberAvatar component
            MemberAvatar.small(member: member)
        }
    }
    
    var body: some View {
        // Make AppState observable/bindable so view updates when its properties change
        @Bindable var appState = appState
        
        NavigationStack(path: $appState.navigationPath) {
            ScrollView(.vertical, showsIndicators: false) {
                // IMPORTANT: GeometryReader must be attached to the inner content
                VStack(spacing: 12) {
                    if !didFinishInitialLoad {
                        // Shimmer skeleton placeholders
                        RedactedGreetingSection()
                        RedactedCardsRow()
                        RedactedStatsRow()
                        RedactedRecentScansSection()
                    } else {
                    // Greeting section
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Hello 👋")
                                .font(NunitoFont.regular.size(14))
                                .foregroundStyle(.grayScale150)

                            Text(primaryMemberName)
                                .font(NunitoFont.semiBold.size(32))
                                .foregroundStyle(.grayScale150)
                                .offset(x: -2)

                            Text("Your food notes, personalized for you.")
                                .font(ManropeFont.regular.size(14))
                                .foregroundStyle(.grayScale130)
                        }

                        Spacer()

                        ProfileCard(isProfileCompleted: true)
                            .onTapGesture {
                                isSettingsPresented = true
                            }
                    }
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)

                    // Food Notes & Allergy Summary...
                    GeometryReader { geometry in
                        let cardWidth = (geometry.size.width - 12) / 2 // 12 is spacing
                        HStack(spacing: 12) {
                            VStack(alignment: .leading) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Food Notes")
                                        .font(ManropeFont.semiBold.size(18))
                                        .foregroundStyle(.grayScale150)
                                        .frame(height: 15)

                                    Text("Here's what your family avoids or needs to watch out for.")
                                        .font(ManropeFont.medium.size(14))
                                        .foregroundStyle(.grayScale110)
                                        .lineLimit(3)
                                }

                                AskIngrediBotButton {
                                    coordinator.showAIBotSheet()
                                }
                            }
                            .frame(width: cardWidth, alignment: .leading)

                            AllergySummaryCard(
                                summary: foodNotesStore.foodNotesSummary,
                                dynamicSteps: onboarding.dynamicSteps,
                                onTap: {
                                    editTargetSectionName = nil
                                    showEditableCanvas = true
                                }
                            )
                            .frame(width: cardWidth, height: 196)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 196)

                    // Family + Average scans - use GeometryReader to ensure equal width
                    GeometryReader { geometry in
                        let cardWidth = (geometry.size.width - 12) / 2 // 12 is spacing
                        HStack(spacing: 12) {
                            AverageScansCard(
                                playsLaunchAnimation: !didPlayAverageScansLaunchAnimation,
                                avgScans: stats?.avgScans ?? 0,
                                weeklyStats: stats?.weeklyStats
                            )
                            .onAppear {
                                didPlayAverageScansLaunchAnimation = true
                            }
                            .frame(width: cardWidth)

                            VStack(alignment: .leading) {
                                Text("Your IngrediFam")
                                    .font(ManropeFont.semiBold.size(18))
                                    .foregroundStyle(.grayScale150)
                                    .padding(.bottom, 4)
                                    .lineLimit(2)

                                Text("Your people, their choices.")
                                    .font(ManropeFont.regular.size(14))
                                    .foregroundStyle(.grayScale110)
                                    .lineLimit(2)

                                Spacer()

                                HStack {
                                    ZStack(alignment: .bottomTrailing) {
                                        let membersToShow = Array(familyMembers.prefix(3))

                                        HStack(spacing: -8) {
                                            ForEach(membersToShow, id: \.id) { member in
                                                FamilyMemberAvatarView(member: member)
                                            }
                                        }

                                        if familyMembers.count > 3 {
                                            Text("+\(familyMembers.count - 3)")
                                                .font(NunitoFont.semiBold.size(12))
                                                .foregroundStyle(.grayScale100)
                                                .background(
                                                    Circle()
                                                        .frame(width: 20, height: 20)
                                                        .foregroundStyle(.grayScale60)
                                                )
                                                .offset(x: 10, y: -2)
                                        }
                                    }

                                    Spacer()

                                    Button {
                                        coordinator.navigateInBottomSheet(.addMoreMembers)
                                    } label: {
                                        GreenCircle(iconName: "tabler_plus", iconSize: 24, circleSize: 36)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(height: 141)
                            .padding(16)
                            .frame(width: cardWidth)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(lineWidth: 0.75)
                                            .foregroundStyle(Color(hex: "#EEEEEE"))
                                    )
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 24))
                            .onTapGesture {
                                // Open Manage Family when tapped
                                appState.navigate(to: .manageFamily)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 173) // Fixed height for the card row (141 content + 16*2 padding)

                    HStack(spacing: 12) {
                        YourBarcodeScans(barcodeScansCount: stats?.barcodeScansCount ?? 0)
                            .frame(maxWidth: .infinity)

                        UserFeedbackCard()
                            .frame(maxWidth: .infinity)

                    }
                    .frame(maxWidth: .infinity)

                    MatchingRateCard(
                        matchedCount: stats?.matchingStats.matched ?? 0,
                        uncertainCount: stats?.matchingStats.uncertain ?? 0,
                        unmatchedCount: stats?.matchingStats.unmatched ?? 0
                    )

                    CreateYourAvatarCard()

                        .onTapGesture {
                            // If family has more than one member, show SetUpAvatarFor first
                            // Otherwise, go directly to YourCurrentAvatar
                            if familyMembers.count > 1 {
                                coordinator.navigateInBottomSheet(.setUpAvatarFor)
                            } else {
                                coordinator.navigateInBottomSheet(.yourCurrentAvatar)
                            }
                        }


                    // Recent Scans Card
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Recent Scans")
                                    .font(ManropeFont.semiBold.size(18))
                                    .foregroundStyle(.grayScale150)

                                Text("Here's what you checked last in past 2 days")
                                    .font(ManropeFont.regular.size(12))
                                    .foregroundStyle(.grayScale100)
                            }

                            Spacer()

                            // Only show "View All" when there are scans
                            if let scans = appState.listsTabState.scans, !scans.isEmpty {
                                NavigationLink(value: HistoryRouteItem.recentScansAll) {
                                    Text("View All")
                                        .underline()
                                        .font(ManropeFont.bold.size(14))
                                        .foregroundStyle(Color(hex: "#82B611"))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Recent Scans list / empty state
                        if let scans = appState.listsTabState.scans,
                           !scans.isEmpty {
                            let items = Array(scans.prefix(5))

                            VStack(spacing: 0) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, scan in

                                    NavigationLink(value: HistoryRouteItem.scan(scan)) {
                                        RecentScanCard(
                                            scan: scan,
                                            style: .compact,
                                            onFavoriteToggle: { scanId, newValue in
                                                handleFavoriteToggle(scanId: scanId, favorited: newValue)
                                            },
                                            onScanUpdated: { updatedScan in
                                                handleScanUpdated(updatedScan)
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    if index != items.count - 1 {
                                        Divider().padding(.vertical, 14)
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image("blackroboicon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                Text("Ooops, No scans yet!")
                                    .font(NunitoFont.semiBold.size(16))
                                    .foregroundStyle(.grayScale100)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(lineWidth: 0.75)
                                    .foregroundStyle(Color(hex: "#EEEEEE"))
                            )
                    )
                    } // end else (real content)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 20)
                .padding(.bottom , 30)
                .padding(.top ,16)
                .navigationBarBackButtonHidden(true)
                // ← Attach GeometryReader here so it measures inside the ScrollView's coordinate space
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                let value = geo.frame(in: .named("homeScroll")).minY
                                scrollTrackingState.prevValue = value
                                scrollTrackingState.maxScrollOffset = value < 0 ? value : 0
                                scrollTrackingState.didInitialize = true
                            }
                            .onChange(of: geo.frame(in: .named("homeScroll")).minY) { newValue in
                                if !scrollTrackingState.didInitialize {
                                    scrollTrackingState.prevValue = newValue
                                    scrollTrackingState.maxScrollOffset = newValue < 0 ? newValue : 0
                                    scrollTrackingState.didInitialize = true
                                    return
                                }
                                
                                // Track the maximum (most negative) scroll offset reached
                                if newValue < 0 {
                                    scrollTrackingState.maxScrollOffset = min(scrollTrackingState.maxScrollOffset, newValue)
                                } else {
                                    scrollTrackingState.maxScrollOffset = 0
                                }
                                
                                let scrollDelta = newValue - scrollTrackingState.prevValue
                                let minScrollDelta: CGFloat = 5 // Minimum scroll change to trigger state change
                                
                                var nextExpanded = isTabBarExpanded
                                
                                // Only change expansion state when scrolled past the top (newValue < 0)
                                if newValue < 0 {
                                    if scrollDelta < -minScrollDelta {
                                        nextExpanded = false
                                    } else if scrollDelta > minScrollDelta {
                                        let bottomThreshold: CGFloat = 100
                                        if newValue > (scrollTrackingState.maxScrollOffset + bottomThreshold) {
                                            nextExpanded = true
                                        }
                                    }
                                }
                                
                                if nextExpanded != isTabBarExpanded {
                                    isTabBarExpanded = nextExpanded
                                }

                                scrollTrackingState.prevValue = newValue

                                // Cancel any pending scroll-end work item
                                scrollTrackingState.scrollEndWorkItem?.cancel()

                                // Schedule re-expansion after scrolling stops (0.4s delay)
                                if !isTabBarExpanded {
                                    let workItem = DispatchWorkItem { [weak scrollTrackingState] in
                                        guard scrollTrackingState != nil else { return }
                                        DispatchQueue.main.async {
                                            withAnimation(.easeOut(duration: 0.25)) {
                                                isTabBarExpanded = true
                                            }
                                        }
                                    }
                                    scrollTrackingState.scrollEndWorkItem = workItem
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
                                }
                            }
                    }
                )
            }
            .scrollBounceBehavior(.basedOnSize)
            .coordinateSpace(name: "homeScroll")
            .frame(maxWidth: .infinity)
            .clipped()
            .withBottomTabBar(
                gradientColors: [
                    Color.white.opacity(0),
                    Color(hex: "#FCFCFE")
                ]
            ) {
                TabBar(
                    isExpanded: $isTabBarExpanded,
                    onRecentScansTap: {
                        appState.navigationPath.append(HistoryRouteItem.recentScansAll)
                    },
                    onChatBotTap: {
                        coordinator.showAIBotSheet()
                    }
                )
            }
            .background(Color.pageBackground)
            //            .padding(.top , 16)
            //            .background(Color.red)
            
            
            // ------------ COORDINATED INITIAL LOAD ------------
                .task {
                    guard !didFinishInitialLoad else { return }
                    let needsScans = appState.listsTabState.scans == nil
                    defer {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            didFinishInitialLoad = true
                        }
                    }
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask { @MainActor in
                            if needsScans {
                                await refreshRecentScans()
                            }
                        }
                        group.addTask { @MainActor in
                            await loadStats()
                        }
                        group.addTask { @MainActor in
                            await foodNotesStore.loadSummaryIfNeeded()
                        }
                        await group.waitForAll()
                    }
                }
            // Trigger a push navigation to Settings when requested by app state
                .onChange(of: appState.navigateToSettings) { _, newValue in
                    if newValue {
                        isSettingsPresented = true
                        appState.navigateToSettings = false
                    }
                }
            // Refresh scan history when returning from ScanCameraView (push navigation)
                .onChange(of: appState.isInScanCameraView) { wasInCamera, isInCamera in
                    // Refresh when leaving camera view (was in camera, now not)
                    if wasInCamera && !isInCamera {
                        Task {
                            await refreshRecentScans()
                        }
                    }
                }
            // Refresh scan history when food preferences are modified
                .onChange(of: appState.needsScanHistoryRefresh) { _, needsRefresh in
                    if needsRefresh {
                        appState.needsScanHistoryRefresh = false
                        Task {
                            await refreshRecentScans()
                        }
                    }
                }
            
            // ------------ SETTINGS SCREEN ------------
            // Use SettingsContentView (without NavigationStack) in navigationDestination
            // to avoid nested NavigationStack issues that cause NavigationPath comparisonTypeMismatch errors
                .navigationDestination(isPresented: $isSettingsPresented) {
                    SettingsContentView()
                        .environment(userPreferences)
                        .environment(coordinator)
                        .environment(memojiStore)
                }
            
            // ------------ EDITABLE CANVAS ------------
                .navigationDestination(isPresented: $showEditableCanvas) {
                    UnifiedCanvasView(
                        mode: .editing,
                        targetSectionName: editTargetSectionName,
                        onDismiss: {
                            showEditableCanvas = false
                        }
                    )
                    .environmentObject(onboarding)
                }

            // ------------ HISTORY ROUTE HANDLING (For Recent Scans) ------------
                .navigationDestination(for: HistoryRouteItem.self) { item in
                    switch item {
                    case .scan(let scan):
                        let product = scan.toProduct()
                        let recommendations = scan.analysis_result?.toIngredientRecommendations()
                        ProductDetailView(
                            scanId: scan.id,
                            initialScan: scan,
                            product: product,
                            matchStatus: scan.toProductRecommendation(),
                            ingredientRecommendations: recommendations,
                            isPlaceholderMode: false,
                            presentationSource: .pushNavigation
                        )
                    case .listItem(let item):
                        // Fallback for list items if reached from Home
                        FavoriteItemDetailView(item: item)  // Assuming FavoriteItemDetailView is available
                    case .favoritesAll:
                        // Fallback, not strictly needed for Recent Scans
                        FavoritesPageView()
                    case .recentScansAll:
                        RecentScansPageView()
                    }
                }
            // ------------ APP ROUTE HANDLING (For ScanCamera, ProductDetail, etc.) ------------
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .scanCamera(let initialMode, let initialScanId):
                        ScanCameraView(initialMode: initialMode, initialScrollTarget: initialScanId, presentationSource: .pushNavigation)
                            .environment(userPreferences)
                            .environment(appState)
                            .environment(scanHistoryStore)
                    case .productDetail(let scanId, let initialScan):
                        ProductDetailView(
                            scanId: scanId,
                            initialScan: initialScan,
                            presentationSource: .pushNavigation
                        )
                    case .favoritesAll:
                        FavoritesPageView()
                            .environment(appState)
                    case .recentScansAll:
                        RecentScansPageView()
                            .environment(appState)
                            .environment(scanHistoryStore)
                    case .favoriteDetail(let item):
                        ProductDetailView(
                            scanId: item.list_item_id,
                            initialScan: nil,
                            presentationSource: .pushNavigation
                        )
                    case .settings:
                        SettingsContentView()
                            .environment(userPreferences)
                            .environment(coordinator)
                            .environment(memojiStore)
                    case .manageFamily:
                        ManageFamilyView()
                            .environment(coordinator)
                    case .editableCanvas(let targetSection):
                        UnifiedCanvasView(mode: .editing, targetSectionName: targetSection)
                            .environment(memojiStore)
                            .environment(coordinator)
                    }
                }
                .onAppear {
                    // Skip shimmer if data is already cached (e.g. returning to tab)
                    if !didFinishInitialLoad {
                        if appState.listsTabState.scans != nil || stats != nil {
                            didFinishInitialLoad = true
                        }
                    }
                }
                .onAppear {
                    // Check if we should auto-open scan camera on app start
                    // Only trigger once when HomeView first appears
                    if !hasCheckedAutoScan && userPreferences.startScanningOnAppStart {
                        hasCheckedAutoScan = true
                        // Small delay to ensure view is fully loaded
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                            // Check camera permission before auto-opening
                            let status = AVCaptureDevice.authorizationStatus(for: .video)
                            if status == .authorized {
                                // Use push navigation instead of modal
                                appState.navigate(to: .scanCamera(initialMode: nil, initialScanId: nil))
                            } else if status == .notDetermined {
                                AVCaptureDevice.requestAccess(for: .video) { granted in
                                    DispatchQueue.main.async {
                                        if granted {
                                            // Use push navigation instead of modal
                                            appState.navigate(to: .scanCamera(initialMode: nil, initialScanId: nil))
                                        }
                                    }
                                }
                            }
                            // If denied/restricted, don't auto-open (user needs to enable in settings)
                        }
                    }
                }

        }
        .overlay(alignment: .bottomTrailing) {
            if shouldShowAIBotFAB {
                AIBotFAB(
                    onTap: { presentAIBotWithContext() },
                    showPromptBubble: coordinator.showFeedbackPromptBubble,
                    onPromptTap: { coordinator.dismissFeedbackPrompt(openChat: true) },
                    onPromptDismiss: { coordinator.dismissFeedbackPrompt(openChat: false) }
                )
                .padding(.trailing, 20)
//                .padding(.bottom, 100)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: shouldShowAIBotFAB)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: coordinator.showFeedbackPromptBubble)
        .tint(Color(hex: "#303030")) // Back button and navigation tint color
        // AI Bot sheet - attached here so it works correctly when Food Notes is shown via navigationDestination
        .sheet(isPresented: Binding(
            get: { coordinator.isAIBotSheetPresented },
            set: { coordinator.isAIBotSheetPresented = $0 }
        ), onDismiss: {
            coordinator.dismissAIBotSheet()
        }) {
            IngrediBotChatView(
                scanId: coordinator.aibotContextScanId,
                analysisId: coordinator.aibotContextAnalysisId,
                ingredientName: coordinator.aibotContextIngredientName,
                feedbackId: coordinator.aibotContextFeedbackId
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .environment(coordinator)
            .environment(appState)
        }
    }

    // MARK: - AIBot FAB

    private var shouldShowAIBotFAB: Bool {
        // Don't show on root (HomeView has its own AIBot buttons)
        guard !appState.navigationPath.isEmpty else { return false }

        // Hide when ScanCameraView is the visible/active view
        // This flag is set by ScanCameraView on appear/disappear
        if appState.isInScanCameraView {
            return false
        }

        // Show on all detail screens (ProductDetailView, etc.)
        return true
    }

    private func presentAIBotWithContext() {
        // Dismiss any feedback prompt bubble first and open chat with pending context
        // (feedback context includes analysisId, ingredientName, feedbackId as needed)
        if coordinator.showFeedbackPromptBubble {
            coordinator.dismissFeedbackPrompt(openChat: true)
            return
        }

        // Try to get context from AppRoute navigation
        // Only pass scanId for product_scan context (not analysisId - that's for feedback)
        if let currentRoute = appState.currentRoute {
            switch currentRoute {
            case .productDetail(let scanId, _):
                coordinator.showAIBotSheetWithContext(scanId: scanId)
                return
            default:
                break
            }
        }

        // Fallback: Check if ProductDetailView has set displayedScanId (for HistoryRouteItem navigation)
        // Only pass scanId for product_scan context
        if let displayedScanId = appState.displayedScanId {
            coordinator.showAIBotSheetWithContext(scanId: displayedScanId)
            return
        }

        // No product context available - open chat with home context
        coordinator.showAIBotSheet()
    }

    private func loadStats() async {
        guard !isLoadingStats else { return }
        isLoadingStats = true
        defer { isLoadingStats = false }
        
        do {
            let fetchedStats = try await webService.fetchStats()
            await MainActor.run {
                stats = fetchedStats
            }
        } catch {
            print("[HomeView] Failed to load stats: \(error.localizedDescription)")
        }
    }
    
    private func refreshRecentScans() async {
        Log.debug("HomeView", "📋 refreshRecentScans called")
        guard !isRefreshingHistory else {
            Log.debug("HomeView", "⏸️ refreshRecentScans skipped - already refreshing")
            return
        }
        isRefreshingHistory = true
        defer { isRefreshingHistory = false }

        Log.debug("HomeView", "📋 refreshRecentScans calling loadHistory")
        // Load via store (single source of truth)
        await scanHistoryStore.loadHistory(limit: 20, offset: 0, forceRefresh: true)
        Log.debug("HomeView", "✅ refreshRecentScans loadHistory completed")

        // Sync store data to AppState for backwards compatibility with ListsTab
        await MainActor.run {
            appState.listsTabState.scans = scanHistoryStore.scans
        }

        // Refresh stats
        await loadStats()
    }

    // MARK: - RecentScanCard Callbacks

    private func handleFavoriteToggle(scanId: String, favorited: Bool) {
        // Update AppState for backwards compatibility
        appState.setHistoryItemFavorited(clientActivityId: scanId, favorited: favorited)

        // Update scan in store and AppState.listsTabState.scans
        if var scans = appState.listsTabState.scans,
           let idx = scans.firstIndex(where: { $0.id == scanId }) {
            let oldScan = scans[idx]
            let newScan = DTO.Scan(
                id: oldScan.id,
                scan_type: oldScan.scan_type,
                barcode: oldScan.barcode,
                state: oldScan.state,
                product_info: oldScan.product_info,
                product_info_source: oldScan.product_info_source,
                product_info_vote: oldScan.product_info_vote,
                analysis_result: oldScan.analysis_result,
                images: oldScan.images,
                latest_guidance: oldScan.latest_guidance,
                created_at: oldScan.created_at,
                last_activity_at: oldScan.last_activity_at,
                is_favorited: favorited,
                analysis_id: oldScan.analysis_id
            )
            scans[idx] = newScan
            appState.listsTabState.scans = scans
            scanHistoryStore.upsertScan(newScan)
        }
    }

    private func handleScanUpdated(_ updatedScan: DTO.Scan) {
        // Update scan in store
        scanHistoryStore.upsertScan(updatedScan)

        // Sync to AppState for backwards compatibility
        if var scans = appState.listsTabState.scans,
           let idx = scans.firstIndex(where: { $0.id == updatedScan.id }) {
            scans[idx] = updatedScan
            appState.listsTabState.scans = scans
        }
    }

    // MARK: - Redacted Shimmer Placeholders

    private struct RedactedGreetingSection: View {
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 80, height: 14)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 160, height: 28)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 220, height: 14)
                }
                Spacer()
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 48, height: 48)
            }
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
            .redacted(reason: .placeholder)
            .shimmering()
        }
    }

    private struct RedactedCardsRow: View {
        var body: some View {
            GeometryReader { geometry in
                let cardWidth = (geometry.size.width - 12) / 2
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.gray.opacity(0.10))
                        .frame(width: cardWidth, height: 196)
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.gray.opacity(0.10))
                        .frame(width: cardWidth, height: 196)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 196)
            .redacted(reason: .placeholder)
            .shimmering()
        }
    }

    private struct RedactedStatsRow: View {
        var body: some View {
            GeometryReader { geometry in
                let cardWidth = (geometry.size.width - 12) / 2
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.gray.opacity(0.10))
                        .frame(width: cardWidth, height: 173)
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.gray.opacity(0.10))
                        .frame(width: cardWidth, height: 173)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 173)
            .redacted(reason: .placeholder)
            .shimmering()
        }
    }

    private struct RedactedRecentScansSection: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header placeholder
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 120, height: 18)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 240, height: 12)
                }

                // Row placeholders
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.10))
                            .frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 140, height: 14)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.10))
                                .frame(width: 100, height: 12)
                        }
                        Spacer()
                    }
                    if index < 2 {
                        Divider()
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(lineWidth: 0.75)
                            .foregroundStyle(Color(hex: "#EEEEEE"))
                    )
            )
            .redacted(reason: .placeholder)
            .shimmering()
        }
    }
}

#Preview {
    let webService = WebService()
    HomeView()
        .environmentObject(Onboarding(onboardingFlowtype: .individual))
        .environment(AppState())
        .environment(webService)
        .environment(ScanHistoryStore(webService: webService))
        .environment(UserPreferences())
        .environment(AuthController())
        .environment(FamilyStore())
        .environment(AppNavigationCoordinator(initialRoute: .home))
        .environment(MemojiStore())
        .environment(ChatStore())
}
