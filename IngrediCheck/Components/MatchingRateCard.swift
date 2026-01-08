//
//  MatchingRateCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/10/25.
//

import SwiftUI

struct MatchingRateCard: View {
    var matchedCount: Int = 0
    var uncertainCount: Int = 00
    var unmatchedCount: Int = 00
    var increaseValue: Int? = nil

    private var totalCount: Int {
        matchedCount + uncertainCount + unmatchedCount
    }

    private var isEmptyState: Bool {
        totalCount <= 0
    }

    private var matchedPercentage: Int {
        guard totalCount > 0 else { return 0 }
        return Int(round((Double(matchedCount) / Double(totalCount)) * 100.0))
    }

    var body: some View {
        VStack( ){
            ZStack {
                Rectangle()
                    .fill(.clear)
                    .frame(width: 230)
                    .overlay(
                        MatchingRateProgressBar(
                            matchedCount: matchedCount,
                            uncertainCount: uncertainCount,
                            unmatchedCount: unmatchedCount
                        )
                            .scaleEffect( UIScreen.main.bounds.width * 0.00217)
                            .offset(y: 35)
                        , alignment: .bottom
                        
                    
                        
                    )
              
                VStack() {
                    HStack(alignment: .bottom, spacing: 0) {
                        Text("\(matchedPercentage)")
                            .font(.system(size: 24, weight: .semibold))
                        
                        Text("%")
                            .font(.system(size: 24, weight: .semibold))
                          
                    }
                    .foregroundStyle(.grayScale150)
                    
                    Text("Matched")
                        .font(ManropeFont.regular.size(13.15))
                        .foregroundStyle(.grayScale100)
                }.offset(y : 35)
                
                if isEmptyState {
                    Text("Start scanning to unlock your matching insights")
                        .font(ManropeFont.regular.size(10))
                        .foregroundStyle(.grayScale120)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(.white)
                                .overlay(
                                    Capsule()
                                        .stroke(Color(hex: "#EEEEEE"), lineWidth: 1)
                                )
                        )
                        .offset(y: 92)
                } else if let increaseValue {
                    MatchingRateCard1(increaseValue: increaseValue)
                        .offset(y: 80)
                }
            }
            
          
           
        }.frame(maxWidth: .infinity  )
            .frame(height: 229)
            .background(.grayScale10, in: RoundedRectangle(cornerRadius: 24))
            .shadow(
                color: isEmptyState ? .clear : Color(hex: "#ECECEC"),
                radius: isEmptyState ? 0 : 9,
                x: 0,
                y: 0
            )
            .overlay(
                Text("Matching Rate")
                    .frame(height: 17)
                    .font(ManropeFont.medium.size(16))
                    .padding(14)
                
                ,alignment: .topLeading
            
                )
           
    }
    
}


struct MatchingRateCard1: View {
    var increaseValue: Int = 20

    var body: some View {
        HStack(spacing: 8) {

            Text("Your matching rate increased by")
                .font(ManropeFont.regular.size(10))
                .lineLimit(1)

           

            HStack(spacing: 6) {
                Image("up-trend")
                    .renderingMode(.template)
                    .frame(width: 16, height: 16)
                   
                Text("+\(increaseValue)")
                    .font(.system(size: 12, weight: .bold))
                  
            }
            .foregroundColor(Color(hex: "#75990E"))
           
            .padding(.vertical, 4)
            .background(
                
                Capsule()
                    .fill(Color(hex: "#E6F6CD"))
                    .frame( width : 56 ,height: 24)
                    .padding(.horizontal, 8)
            )
        }
        .padding(.horizontal, 12)
        .frame(height: 32) // ✅ works correctly now
//        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
        )
    }
}



#Preview {
    Group {
        // Filled state preview
        ZStack {
            Color.gray.opacity(0.1).ignoresSafeArea()
            MatchingRateCard(matchedCount: 0, uncertainCount: 0, unmatchedCount: 47, increaseValue: 20)
                .padding(.horizontal, 20)
        }
        .previewDisplayName("Filled State")
        
        // Empty state preview
        ZStack {
            Color.gray.opacity(0.9).ignoresSafeArea()
            MatchingRateCard(matchedCount: 0, uncertainCount: 0, unmatchedCount: 0)
                .padding(.horizontal, 20)
        }
        .previewDisplayName("Empty State")
    }
}
