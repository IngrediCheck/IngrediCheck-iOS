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

    // ---------------------------
    // MERGED FROM YOUR BRANCH
    // ---------------------------
    private struct ProductDetailPayload: Identifiable {
        let id = UUID()
        let product: DTO.Product
        let matchStatus: DTO.ProductRecommendation
        let ingredientRecommendations: [DTO.IngredientRecommendation]?
    }

    @State private var activeProductDetail: ProductDetailPayload?

    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService
    @Environment(UserPreferences.self) var userPreferences
    @Environment(AuthController.self) private var authController

    // ---------------------------
    // MERGED FROM DEVELOP BRANCH
    // ---------------------------
    @Environment(FamilyStore.self) private var familyStore
    @Environment(AppNavigationCoordinator.self) private var coordinator

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
        @Environment(WebService.self) private var webService
        let member: FamilyMember
        
        @State private var avatarImage: UIImage? = nil
        @State private var loadedHash: String? = nil
        
        var body: some View {
            // Base colored circle - always visible as background
            Circle()
                .fill(Color(hex: member.color))
                .frame(width: 36, height: 36)
                .overlay {
                    // Content layer overlaid on background
                    if let avatarImage {
                        // Show loaded memoji avatar - slightly smaller to show background border
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        // Fallback: first letter of name
                        Text(String(member.name.prefix(1)))
                            .font(NunitoFont.semiBold.size(14))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(
                    // White stroke overlay on top
                    Circle()
                        .stroke(lineWidth: 1)
                        .foregroundStyle(Color.white)
                )
                // Re-evaluate whenever the member's imageFileHash changes.
                .task(id: member.imageFileHash) {
                    await loadAvatarForCurrentHash()
                }
        }
        
        @MainActor
        private func loadAvatarForCurrentHash() async {
            // If there is no hash, clear any cached avatar and fall back to initials.
            guard let hash = member.imageFileHash, !hash.isEmpty else {
                if avatarImage != nil {
                    print("[HomeView.FamilyMemberAvatarView] imageFileHash cleared for \(member.name), resetting avatarImage")
                }
                avatarImage = nil
                loadedHash = nil
                return
            }

            // If we've already loaded this exact hash, skip re-fetching.
            if loadedHash == hash, avatarImage != nil {
                print("[HomeView.FamilyMemberAvatarView] Avatar for \(member.name) already loaded for hash \(hash), skipping reload")
                return
            }
            
            print("[HomeView.FamilyMemberAvatarView] Loading avatar for \(member.name), imageFileHash=\(hash)")
            do {
                let uiImage = try await webService.fetchImage(
                    imageLocation: .imageFileHash(hash),
                    imageSize: .small
                )
                avatarImage = uiImage
                loadedHash = hash
                print("[HomeView.FamilyMemberAvatarView] ✅ Loaded avatar for \(member.name) (hash=\(hash))")
            } catch {
                print("[HomeView.FamilyMemberAvatarView] ❌ Failed to load avatar for \(member.name): \(error.localizedDescription)")
            }
        }
    }

    var body: some View {
        NavigationStack {
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

                        AllergySummaryCard()
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.22)
                    .padding(.bottom, 24)

                    // Lifestyle + Family + Average scans
                    HStack {
                        LifestyleAndChoicesCard()
                    
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
                            NavigationLink {
                                RecentScansPageView()
                            } label: {
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
            ).offset( y: 30)
            .overlay(
                TabBar(isExpanded: $isTabBarExpanded),
                alignment: .bottom
            )
            .background(Color.white)

            // ------------ HISTORY LOADING ------------
            .task {
                if appState.listsTabState.scans == nil {
                    await refreshRecentScans()
                }
            }

            // ------------ SETTINGS SCREEN ------------
            .navigationDestination(isPresented: $isSettingsPresented) {
                SettingsSheet()
                    .environment(userPreferences)
                    .environment(coordinator)
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
                    product: detail.product,
                    matchStatus: detail.matchStatus,
                    ingredientRecommendations: detail.ingredientRecommendations,
                    isPlaceholderMode: false
                )
            }

        }
    }

    private func refreshRecentScans() async {
        guard !isRefreshingHistory else { return }
        isRefreshingHistory = true
        defer { isRefreshingHistory = false }

        if let historyResponse = try? await webService.fetchScanHistory(limit: 20, offset: 0) {
            await MainActor.run {
                appState.listsTabState.scans = historyResponse.scans
            }
        }
    }
}

#Preview {
    HomeView()
}
