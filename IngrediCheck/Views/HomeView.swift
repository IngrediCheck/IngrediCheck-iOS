
//
//  HomeView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar on 10/11/25.
//

import SwiftUI

struct HomeView: View {
    private let chatSmallDetent: PresentationDetent = .height(260)
    @State private var isChatSheetPresented = false
    @State private var selectedChatDetent: PresentationDetent = .medium
    @State private var isSettingsPresented = false
    @State private var isTabBarExpanded: Bool = true
    @State private var isRefreshingHistory: Bool = false
    @State private var showEditableCanvas: Bool = false
    @State private var editTargetSectionName: String? = nil
    @State private var navigationPath: [HistoryRouteItem] = []
    @SceneStorage("didPlayAverageScansLaunchAnimation") private var didPlayAverageScansLaunchAnimation: Bool = false

    private final class ScrollTrackingState {
        var prevValue: CGFloat = 0
        var maxScrollOffset: CGFloat = 0
        var didInitialize: Bool = false
    }

    @State private var scrollTrackingState = ScrollTrackingState()
    @State private var stats: DTO.StatsResponse? = nil
    @State private var isLoadingStats: Bool = false
    @State private var showScanCamera: Bool = false
    @State private var hasCheckedAutoScan: Bool = false
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
    
    @State private var activeProductDetail: ProductDetailPayload?
    
    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService
    @Environment(ScanHistoryStore.self) var scanHistoryStore
    @Environment(UserPreferences.self) var userPreferences
    @Environment(AuthController.self) private var authController
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
        return familyStore.family?.selfMember.name ?? "IngrediFriend"
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
        NavigationStack(path: $navigationPath) {
            ScrollView(.vertical, showsIndicators: false) {
                // IMPORTANT: GeometryReader must be attached to the inner content
                VStack(spacing: 0) {
                    
                    // Greeting section
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 3) {
                                Text("Hello")
                                    .font(NunitoFont.regular.size(14))
                                    .foregroundStyle(.grayScale150)
                                
                                Text("👋")
                                    .font(.system(size: 10))
                                    .padding(.bottom, 1)
                            }
                            .frame(height: 16)
                            
                            Text(primaryMemberName)
                                .font(NunitoFont.semiBold.size(32))
                                .foregroundStyle(.grayScale150)
                                .frame(height: 28)
                                .offset(x: -1.8)
                            
                            Text("Complete your profile easily.")
                                .font(ManropeFont.regular.size(12))
                                .foregroundStyle(.grayScale100)
                                .frame(height: 16)
                        }
                        
                        Spacer()
                        
                        ProfileCard(isProfileCompleted: true)
                            .onTapGesture {
                                isSettingsPresented = true
                            }
                    }
                    .padding(.bottom, 28)
                    
                    // Food Notes & Allergy Summary...
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Food Notes")
                                    .font(ManropeFont.semiBold.size(18))
                                    .foregroundStyle(.grayScale150)
                                    .frame(height: 15)
                                
                                Text("Here's what your family avoids  or needs to watch out for.")
                                    .font(ManropeFont.regular.size(12))
                                    .foregroundStyle(.grayScale100)
                            }
                            Spacer()
                            
                            AskIngrediBotButton {
                                selectedChatDetent = .medium
                                isChatSheetPresented = true
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        
                        AllergySummaryCard(onTap: {
                            editTargetSectionName = nil
                            showEditableCanvas = true
                        })
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.22)
                    .padding(.bottom, 24)
                    
                    // Family + Average scans
                    HStack(spacing: 12) {
                        AverageScansCard(
                            playsLaunchAnimation: !didPlayAverageScansLaunchAnimation,
                            avgScans: stats?.avgScans ?? 0
                        )
                            .onAppear {
                                didPlayAverageScansLaunchAnimation = true
                            }
                            .frame(maxWidth: .infinity)
                        
                        VStack {
                            VStack(alignment: .leading) {
                                Text("Your IngrediFam")
                                    .font(ManropeFont.medium.size(18))
                                    .foregroundStyle(.grayScale150)
                                    .padding(.bottom, 4)
                            
                                Text("Your people, their choices.")
                                    .font(ManropeFont.regular.size(12))
                                    .foregroundStyle(.grayScale100)
                                
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
                            .frame(height: 125)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, 20)
                    
                    Image(.homescreenbanner)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(20)
                        .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
                        .padding(.bottom, 20)
                    
                    HStack(spacing: 12) {
                        YourBarcodeScans(barcodeScansCount: stats?.barcodeScansCount ?? 0)
                            .frame(maxWidth: .infinity)
                        UserFeedbackCard()
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, 20)
                    
                    MatchingRateCard(
                        matchedCount: stats?.matchingStats.matched ?? 0,
                        uncertainCount: stats?.matchingStats.uncertain ?? 0,
                        unmatchedCount: stats?.matchingStats.unmatched ?? 0
                    )
                        .padding(.bottom, 20)
                    
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
                        .padding(.bottom, 20)
                    
                    
                    // Recent Scans header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing : 6) {
                                Text("Recent Scans")
                                    .font(ManropeFont.medium.size(18))
                                    .foregroundStyle(.grayScale150)
                                
                                Button {
                                    Task {
                                        await refreshRecentScans()
                                    }
                                } label: {
                                    if isRefreshingHistory {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Color(hex: "B6B6B6"))
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isRefreshingHistory)
                            }
                            
                            Text("Here’s what you checked last in past 2 days")
                                .font(ManropeFont.regular.size(12))
                                .foregroundStyle(.grayScale100)
                        }
                        
                        Spacer()
                        
                        // KEEP YOUR SHEET VERSION
                        HStack(spacing: 6) {
                            NavigationLink(value: HistoryRouteItem.recentScansAll) {
                                Text("View All")
                                    .underline()
                                    .font(ManropeFont.medium.size(14))
                                    .foregroundStyle(Color(hex: "B6B6B6"))
                            }
                            .buttonStyle(.plain)
                            
                            //                            Button {
                            //                                Task {
                            //                                    await refreshRecentScans()
                            //                                }
                            //                            } label: {
                            //                                if isRefreshingHistory {
                            //                                    ProgressView()
                            //                                        .progressViewStyle(.circular)
                            //                                        .scaleEffect(0.7)
                            //                                } else {
                            //                                    Image(systemName: "arrow.clockwise")
                            //                                        .font(.system(size: 14, weight: .medium))
                            //                                }
                            //                            }
                            //                            .buttonStyle(.plain)
                            //                            .disabled(isRefreshingHistory)
                        }
                    }
                    .padding(.bottom, 20)
                    
                    // Recent Scans list / empty state
                    if let scans = appState.listsTabState.scans,
                       !scans.isEmpty {
                        let items = Array(scans.prefix(5))
                        
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, scan in
                                
                                Button {
                                    let product = scan.toProduct()
                                    let recommendations = scan.analysis_result?.toIngredientRecommendations()
                                    
                                    let payload = ProductDetailPayload(
                                        scanId: scan.id,
                                        scan: scan,
                                        product: product,
                                        matchStatus: scan.toProductRecommendation(),
                                        ingredientRecommendations: recommendations,
                                        clientActivityId: nil,
                                        favorited: scan.is_favorited ?? false
                                    )
                                    
                                    activeProductDetail = payload
                                    
                                } label: {
                                    ScanRow(scan: scan)
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
                        .padding(.top , 8)
                        .padding(.bottom , 129)
                    }
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
                            }
                    }
                )
            }
            .scrollBounceBehavior(.basedOnSize)
            .coordinateSpace(name: "homeScroll")
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(
                // Bottom gradient - positioned behind everything, flush with bottom (ignores safe area)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color(hex: "#FCFCFE"),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 132)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false),
                alignment: .bottom
            ).ignoresSafeArea(edges: .bottom)
            .overlay(
                // TabBar in its original position (respects safe area)
                TabBar(
                    isExpanded: $isTabBarExpanded,
                    onRecentScansTap: {
                        navigationPath.append(.recentScansAll)
                    },
                    onChatBotTap: {
                        selectedChatDetent = .medium
                        isChatSheetPresented = true
                    }
                ),
                alignment: .bottom
            )
            .background(Color.white)
//            .padding(.top , 16)
//            .background(Color.red)
            
           
            // ------------ HISTORY LOADING ------------
            .task {
                if appState.listsTabState.scans == nil {
                    await refreshRecentScans()
                }
            }
            // Trigger a push navigation to Settings when requested by app state
            .onChange(of: appState.navigateToSettings) { _, newValue in
                if newValue {
                    isSettingsPresented = true
                    appState.navigateToSettings = false
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
                EditableCanvasView(
                    targetSectionName: editTargetSectionName,
                    onBack: {
                        showEditableCanvas = false
                    }
                )
                    .environmentObject(onboarding)
            }
            


            // ------------ CHAT SHEET ------------
            .sheet(isPresented: $isChatSheetPresented) {
                IngrediBotChatView {
                    isChatSheetPresented = false
                }
                .presentationDetents([chatSmallDetent, .medium, .large],
                                     selection: $selectedChatDetent)
                .presentationDragIndicator(.visible)
            }

            // ------------ PRODUCT DETAIL ------------
            .fullScreenCover(item: $activeProductDetail) { detail in
                ProductDetailView(
                    scanId: detail.scanId,  // Pass scanId for real-time updates
                    initialScan: detail.scan,  // Pass full scan with is_favorited
                    product: detail.product,
                    matchStatus: detail.matchStatus,
                    ingredientRecommendations: detail.ingredientRecommendations,
                    isPlaceholderMode: false,
                    presentationSource: .homeView
                )
            }
            
            // ------------ SCAN CAMERA (Auto-open on app start) ------------
            .fullScreenCover(isPresented: $showScanCamera, onDismiss: {
                Task {
                    await scanHistoryStore.loadHistory(forceRefresh: true)
                    // Also refresh scan count since a new scan might have occurred
                    userPreferences.refreshScanCount()
                }
            }) {
                ScanCameraView()
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
                        presentationSource: .homeView
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
            .task {
                await loadStats()
            }
            .onAppear {
                // Check if we should auto-open scan camera on app start
                // Only trigger once when HomeView first appears
                if !hasCheckedAutoScan && userPreferences.startScanningOnAppStart {
                    hasCheckedAutoScan = true
                    // Small delay to ensure view is fully loaded
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                        showScanCamera = true
                    }
                }
            }
            
        }
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
}

#Preview {
    HomeView()
        .environmentObject(Onboarding(onboardingFlowtype: .individual))
        .environment(AppState())
        .environment(WebService())
        .environment(UserPreferences())
        .environment(AuthController())
        .environment(FamilyStore())
        .environment(AppNavigationCoordinator(initialRoute: .home))
}
