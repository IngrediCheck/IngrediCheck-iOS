
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
    @State private var scrollY: CGFloat = 0
    @State private var prevValue: CGFloat = 0
    @State private var maxScrollOffset: CGFloat = 0
    @State private var isRefreshingHistory: Bool = false
    @State private var showEditableCanvas: Bool = false
    @State private var editTargetSectionName: String? = nil
    @State private var navigationPath: [HistoryRouteItem] = []
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
            ScrollView(showsIndicators: false) {
                // IMPORTANT: GeometryReader must be attached to the inner content
                VStack(spacing: 0) {
                    
                    // Greeting section
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
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
                    HStack {
                        VStack(alignment: .leading) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Food Notes")
                                    .font(ManropeFont.semiBold.size(18))
                                    .foregroundStyle(.grayScale150)
                                    .frame(height: 15)
                                
                                Text("Here’s what your family avoids  or needs to watch out for.")
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
                        
                        Spacer()
                        AllergySummaryCard(onTap: {
                            editTargetSectionName = nil
                            showEditableCanvas = true
                        })
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.22)
                    .padding(.bottom, 24)
                    
                    // Lifestyle + Family + Average scans
                    HStack {
                        LifestyleAndChoicesCard(onTap: {
                            // Request centering of Lifestyle/Nutrition when opening editor
                            editTargetSectionName = "Lifestyle"
                            showEditableCanvas = true
                        })
                        Spacer()
                        
                        VStack {
                            VStack(alignment: .leading) {
                                Text("Your IngrediFam")
                                    .font(ManropeFont.medium.size(18))
                                    .foregroundStyle(.grayScale150)
                                
                                Text("Your people, their choices.")
                                    .font(ManropeFont.regular.size(12))
                                    .foregroundStyle(.grayScale100)
                                
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
                            .frame(height: 103)
                            
                            AverageScansCard()
                        }
                    }
                    .padding(.bottom, 20)
                    
                    Image(.homescreenbanner)
                        .resizable()
                        .cornerRadius(20)
                        .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
                        .padding(.bottom, 20)
                    
                    HStack {
                        YourBarcodeScans()
                        UserFeedbackCard()
                    }
                    .padding(.bottom, 20)
                    
                    MatchingRateCard()
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
                                        ingredientRecommendations: recommendations
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
                .padding(.horizontal, 20)
                .padding(.bottom , 30)
                .navigationBarBackButtonHidden(true)
                // ← Attach GeometryReader here so it measures inside the ScrollView's coordinate space
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                scrollY = geo.frame(in: .named("homeScroll")).minY
                                prevValue = scrollY
                                maxScrollOffset = scrollY < 0 ? scrollY : 0
                            }
                            .onChange(of: geo.frame(in: .named("homeScroll")).minY) { newValue in
                                scrollY = newValue
                                
                                // Only change state when scrolled past the top (scrollY < 0)
                                if scrollY < 0 {
                                    // Track the maximum (most negative) scroll offset reached
                                    maxScrollOffset = min(maxScrollOffset, newValue)
                                    
                                    let scrollDelta = newValue - prevValue
                                    let minScrollDelta: CGFloat = 5 // Minimum scroll change to trigger state change
                                    
                                    if scrollDelta < -minScrollDelta {
                                        // Scrolling down significantly -> collapse
                                        isTabBarExpanded = false
                                    } else if scrollDelta > minScrollDelta {
                                        // Only expand if scrolling up significantly AND not at the bottom
                                        // Check if we're significantly above the maximum scroll offset
                                        let bottomThreshold: CGFloat = 100 // Minimum distance from bottom to allow expansion
                                        if newValue > (maxScrollOffset + bottomThreshold) {
                                            isTabBarExpanded = true
                                        }
                                    }
                                    // If scrollDelta is too small (bounce/noise), don't change state
                                } else {
                                    // Reset max scroll offset when at the top
                                    maxScrollOffset = 0
                                }
                                
                                prevValue = newValue
                            }
                    }
                )
            }
            .scrollBounceBehavior(.basedOnSize)
            .coordinateSpace(name: "homeScroll")
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
                TabBar(isExpanded: $isTabBarExpanded, onRecentScansTap: {
                    navigationPath.append(.recentScansAll)
                }),
                alignment: .bottom
            )
            .background(Color.white)
           
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
            .navigationDestination(isPresented: $isSettingsPresented) {
                SettingsSheet()
                    .environment(userPreferences)
                    .environment(coordinator)
                    .environment(memojiStore)
            }
            
            // ------------ EDITABLE CANVAS ------------
            .navigationDestination(isPresented: $showEditableCanvas) {
                EditableCanvasView(targetSectionName: editTargetSectionName)
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
            
        }
    }
    
    private func refreshRecentScans() async {
        guard !isRefreshingHistory else { return }
        isRefreshingHistory = true
        defer { isRefreshingHistory = false }

        // Load via store (single source of truth)
        await scanHistoryStore.loadHistory(limit: 20, offset: 0, forceRefresh: true)

        // Sync store data to AppState for backwards compatibility with ListsTab
        await MainActor.run {
            appState.listsTabState.scans = scanHistoryStore.scans
        }
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
