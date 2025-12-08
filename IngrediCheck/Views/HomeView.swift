//
//  HomeView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

struct HomeView: View {
    private let chatSmallDetent: PresentationDetent = .height(260)
    @State private var isChatSheetPresented = false
    @State private var selectedChatDetent: PresentationDetent = .medium
    @State private var isProductDetailPresented = false
    @State private var isRecentScansPresented = false
    @State private var isTabBarExpanded: Bool = true
    @State private var previousScrollOffset: CGFloat = 0
    @State private var collapseReferenceOffset: CGFloat = 0
    @Environment(FamilyStore.self) private var familyStore
    
    private var familyMembers: [FamilyMember] {
        guard let family = familyStore.family else { return [] }
        return [family.selfMember] + family.otherMembers
    }
    
    private var primaryMemberName: String {
        familyStore.family?.selfMember.name ?? "IngrediFriend"
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                
                // Greeting and profilecard
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
                }
                .padding(.bottom, 28)
                
                
                // Food Notes and Allergy Summary card
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
                
                
                // Lifestyle & choices and average scans cards
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
                                                        .foregroundStyle(Color(hex: "FFFFFF"))
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
                                
                                GreenCircle(iconName: "tabler_plus", iconSize: 24, circleSize: 36)
                            }
                        }
                        .frame(height: 103)
                        
                        AverageScansCard()
                    
                    }
                }
                .padding(.bottom, 20)
                
                
                // homescreen banner
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
                
                // matching rate card
                MatchingRateCard()
                    .padding(.bottom, 20)
                
                // create your own avatar card
                CreateYourAvatarCard()
                    .padding(.bottom, 20)
                
                // Recent Scans
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recent Scans")
                            .font(ManropeFont.medium.size(18))
                            .foregroundStyle(.grayScale150)
                        Text("Here’s what you checked last in past 2 days")
                            .font(ManropeFont.regular.size(12))
                            .foregroundStyle(.grayScale100)
                    }
                    
                    Spacer()
                    
                    Button {
                        isRecentScansPresented = true
                    } label: {
                        Text("View All")
                            .underline()
                            .font(ManropeFont.medium.size(14))
                            .foregroundStyle(Color(hex: "B6B6B6"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 20)
                
                //Recent Scans List Items
                VStack(spacing: 0) {
                    ForEach(0..<5) { ele in
                        Button {
                            isProductDetailPresented = true
                        } label: {
                            RecentScansRow()
                        }
                        .buttonStyle(.plain)
                        
                        if ele != 4 {
                            Divider()
                                .padding(.vertical, 14)
                        }
                        
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 90)
            .navigationBarBackButtonHidden(true)
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
        .background(Color(hex: "FFFFFF"))
        .sheet(isPresented: $isChatSheetPresented) {
            IngrediBotChatView {
                isChatSheetPresented = false
            }
            .presentationDetents([chatSmallDetent, .medium, .large], selection: $selectedChatDetent)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isProductDetailPresented) {
            ProductDetailView()
        }
        .sheet(isPresented: $isRecentScansPresented) {
            RecentScansFullView()
        }
    }
    
}


#Preview {
    HomeView()
}

