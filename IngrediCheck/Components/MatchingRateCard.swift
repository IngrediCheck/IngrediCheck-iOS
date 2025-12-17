//
//  MatchingRateCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/10/25.
//

import SwiftUI

struct MatchingRateCard: View {
    var body: some View {
        VStack( ){
            ZStack {
                Rectangle()
                    .fill(.clear)
                    .frame(width: 230)
                    .overlay(
                        MatchingRateProgressBar(matchedCount: 78, uncertainCount: 31, unmatchedCount: 47)
                            .scaleEffect( UIScreen.main.bounds.width * 0.00217)
                            .offset(y: 45)
                        , alignment: .bottom
                        
                    
                        
                    )
              
                VStack() {
                    HStack(alignment: .bottom, spacing: 0) {
                        Text("140")
                            .font(.system(size: 24, weight: .semibold))
                        
                        Text("%")
                            .font(.system(size: 24, weight: .semibold))
                          
                    }
                    .foregroundStyle(.grayScale150)
                    
                    Text("Matched")
                        .font(ManropeFont.regular.size(13.15))
                        .foregroundStyle(.grayScale100)
                }.offset(y : 35)
                
                MatchingRateCard1(increaseValue: 20)
                    .offset(y: 90)
            }
            
          
           
        }.frame(maxWidth: .infinity  )
            .frame(height: 229)
            .background(.grayScale10, in: RoundedRectangle(cornerRadius: 24))
                .shadow(color: Color(hex: "#ECECEC"), radius: 9, x: 0, y: 0)
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
//    MatchingRateCard1(increaseValue: 20)
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        MatchingRateCard()
            .padding(.horizontal, 20)
    }
}
