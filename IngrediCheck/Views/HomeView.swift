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
    @State private var isProductDetailPresented = false
    @State private var isRecentScansPresented = false
    @State private var isSettingsPresented = false
    @State private var isTabBarExpanded: Bool = true
    @State private var previousScrollOffset: CGFloat = 0
    @State private var collapseReferenceOffset: CGFloat = 0
    @State private var isRefreshingHistory: Bool = false

    // ---------------------------
    // MERGED FROM YOUR BRANCH
    // ---------------------------
    @State private var selectedProduct: DTO.Product? = nil
    @State private var selectedMatchStatus: DTO.ProductRecommendation? = nil
    @State private var selectedIngredientRecommendations: [DTO.IngredientRecommendation]? = nil

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

                        ProfileCard(isProfileCompleted: false)
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
                                                Circle()
                                                    .fill(Color(hex: member.color))
                                                    .frame(width: 36, height: 36)
                                                    .overlay(
                                                        Text(String(member.name.prefix(1)))
                                                            .font(NunitoFont.semiBold.size(14))
                                                            .foregroundStyle(.white)
                                                    )
                                                    .overlay(
                                                        Circle()
                                                            .stroke(lineWidth: 1)
                                                            .foregroundStyle(Color.white)
                                                    )
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
                            Button {
                                isRecentScansPresented = true
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

                    // Recent Scans list
                    if let historyItems = appState.listsTabState.historyItems {
                        let items = Array(historyItems.prefix(5))

                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.client_activity_id) { index, item in

                                Button {
                                    let product = DTO.Product(
                                        barcode: item.barcode,
                                        brand: item.brand,
                                        name: item.name,
                                        ingredients: item.ingredients,
                                        images: item.images
                                    )

                                    selectedProduct = product
                                    selectedMatchStatus = item.calculateMatch()
                                    selectedIngredientRecommendations = item.ingredient_recommendations
                                    isProductDetailPresented = true

                                } label: {
                                    HomeRecentScanRow(item: item)
                                }
                                .buttonStyle(.plain)

                                if index != items.count - 1 {
                                    Divider().padding(.vertical, 14)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 90)
                .navigationBarBackButtonHidden(true)
                // ← Attach GeometryReader here so it measures inside the ScrollView's coordinate space
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                previousScrollOffset = geo.frame(in: .named("homeScroll")).minY
                                collapseReferenceOffset = previousScrollOffset
                            }
                            .onChange(of: geo.frame(in: .named("homeScroll")).minY) { newValue in
                                let currentOffset = newValue
                                let threshold: CGFloat = 8           // minimum meaningful movement per frame
                                let topGuardOffset: CGFloat = -12    // how far past top before we consider expansion
                                let requiredLiftFromBottom: CGFloat = 180 // distance user must scroll up from bottom to expand

                                // Only react to scroll changes when we're within the "normal"
                                // scroll range (offset <= 0). This avoids reacting to rubber-band
                                // stretching at the very top (offset > 0).
                                if currentOffset <= 0 && previousScrollOffset <= 0 {
                                    let delta = currentOffset - previousScrollOffset

                                    // When user scrolls down with a meaningful movement -> collapse.
                                    // When user scrolls up with a meaningful movement -> expand.
                                    // Ignore tiny bounces so the tab bar doesn't flicker or auto-expand.
                                    if delta < -threshold {
                                        isTabBarExpanded = false

                                        // Track the deepest (most negative) offset reached since we
                                        // last collapsed; this is our "bottom reference" to compare
                                        // against when deciding whether an upward motion is just a
                                        // spring-back or a real intent to scroll up.
                                        if collapseReferenceOffset == 0 {
                                            collapseReferenceOffset = currentOffset
                                        } else {
                                            collapseReferenceOffset = min(collapseReferenceOffset, currentOffset)
                                        }
                                    } else if delta > threshold {
                                        // Only allow expansion when:
                                        // - we're safely away from the very top, AND
                                        // - the user has moved a meaningful distance up from the
                                        //   deepest offset reached since collapsing (to avoid
                                        //   spring-back-at-bottom from expanding the tab bar).
                                        let distanceFromBottom = currentOffset - collapseReferenceOffset

                                        if distanceFromBottom > requiredLiftFromBottom,
                                           currentOffset < topGuardOffset,
                                           previousScrollOffset < topGuardOffset {
                                            isTabBarExpanded = true
                                            // Reset the reference for the next cycle.
                                            collapseReferenceOffset = currentOffset
                                        }
                                    }
                                }

                                previousScrollOffset = currentOffset
                            }
                    }
                )
            }
            .coordinateSpace(name: "homeScroll")
            .overlay(
                TabBar(isExpanded: $isTabBarExpanded),
                alignment: .bottom
            )
            .background(Color.white)

            // ------------ HISTORY LOADING ------------
            .task {
                if appState.listsTabState.historyItems == nil {
                    await refreshRecentScans()
                }
            }

            // ------------ SETTINGS SHEET ------------
            .sheet(isPresented: $isSettingsPresented) {
                SettingsSheet()
                    .environment(userPreferences)
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
            .fullScreenCover(isPresented: $isProductDetailPresented) {
                if let product = selectedProduct {
                    ProductDetailView(
                        product: product,
                        matchStatus: selectedMatchStatus,
                        ingredientRecommendations: selectedIngredientRecommendations,
                        isPlaceholderMode: false
                    )
                } else {
                    ProductDetailView(isPlaceholderMode: true)
                }
            }

            // ------------ RECENT SCANS SHEET ------------
            .fullScreenCover(isPresented: $isRecentScansPresented) {
                NavigationStack {
                    RecentScansPageView()
                }
                .environment(userPreferences)
            }
        }
    }

    private func refreshRecentScans() async {
        guard !isRefreshingHistory else { return }
        isRefreshingHistory = true
        defer { isRefreshingHistory = false }

        if let history = try? await webService.fetchHistory() {
            await MainActor.run {
                appState.listsTabState.historyItems = history
            }
        }
    }
}

#Preview {
    HomeView()
}
