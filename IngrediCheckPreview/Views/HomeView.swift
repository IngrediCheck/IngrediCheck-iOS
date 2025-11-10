//
//  HomeView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

struct HomeView: View {
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
                        
                        Text("Ritika")
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
                        
                        AskIngrediBotButton()
                    }
                    .frame(height: 196)
                    
                    Spacer()
                    
                    AllergySummaryCard()
                }
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
                                    HStack(spacing: -8) {
                                        Image(.imageBg1)
                                            .resizable()
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle()
                                                    .stroke(lineWidth: 1)
                                                    .foregroundStyle(Color(hex: "FFFFFF"))
                                            )
                                        
                                        Image(.imageBg2)
                                            .resizable()
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle()
                                                    .stroke(lineWidth: 1)
                                                    .foregroundStyle(Color(hex: "FFFFFF"))
                                            )
                                        
                                        Image(.imageBg3)
                                            .resizable()
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle()
                                                    .stroke(lineWidth: 1)
                                                    .foregroundStyle(Color(hex: "FFFFFF"))
                                            )
                                    }
                                    
                                    Text("+3")
                                        .font(NunitoFont.semiBold.size(12))
                                        .foregroundStyle(.grayScale100)
                                        .background(
                                            Circle()
                                                .frame(width: 20, height: 20)
                                                .foregroundStyle(.grayScale60)
                                        )
                                        .offset(x: 10, y: -2)
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
                    
                    Text("View All")
                        .underline()
                        .font(ManropeFont.medium.size(14))
                        .foregroundStyle(Color(hex: "B6B6B6"))
                }
                .padding(.bottom, 20)
                
                //Recent Scans List Items
                VStack(spacing: 0) {
                    ForEach(0..<5) { ele in
                        RecentScansRow()
                        
                        if ele != 4 {
                            Divider()
                                .padding(.vertical, 14)
                        }
                        
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 90)
        }
        .overlay(
            TabBar(isExpanded: .constant(true))
            , alignment: .bottom
        )
        .background(Color(hex: "FFFFFF"))
    }
    
}


#Preview("iPhone 13 mini") {
    HomeView()
        .previewDevice("iPhone 13 mini")
}

#Preview("iPhone 16 Pro") {
    HomeView()
        .previewDevice("iPhone 16 Pro")
}
