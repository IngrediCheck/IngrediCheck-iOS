//
//  MatchingRateCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/10/25.
//

import SwiftUI

struct MatchingRateCard: View {
    var body: some View {
        //        HStack {
        //
        //
        //
        //        }
        //        .padding(.horizontal, 12)
        //        .frame(height: 125)
        //        .background(.grayScale10, in: RoundedRectangle(cornerRadius: 24))
        //        .shadow(color: Color(hex: "#ECECEC"), radius: 9, x: 0, y: 0)
        //        .overlay(
        VStack(alignment: .leading ){
            
            Text("Matching Rate")
                .font(ManropeFont.medium.size(16))
                .padding(.leading , 20)
                .padding(.top,13)
                
            ZStack {
                Rectangle()
                    .fill(.clear)
                    .frame(width: 200)
                    .overlay(
                        MatchingRateProgressBar(filledSegments: 7)
                            .scaleEffect(UIScreen.main.bounds.width * 0.00165)
                            .offset(y: 15)
                        , alignment: .center
                    )
                
                VStack(alignment: .center, spacing: 0) {
                    HStack(alignment: .bottom, spacing: 0) {
                        Text("140")
                            .font(.system(size: 24, weight: .semibold))
                        
                        Text("%")
                            .font(.system(size: 8, weight: .semibold))
                            .padding(.bottom, 5)
                    }
                    .foregroundStyle(.grayScale150)
                    
                    Text("Matched")
                        .font(ManropeFont.regular.size(10))
                        .foregroundStyle(.grayScale100)
                }
            }
            
       
        }.frame(maxWidth: .infinity  )
            .frame(height: 229)
            .background(.grayScale10, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color(hex: "#ECECEC"), radius: 9, x: 0, y: 0)
    }
}
#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        MatchingRateCard()
            .padding(.horizontal, 20)
    }
}
