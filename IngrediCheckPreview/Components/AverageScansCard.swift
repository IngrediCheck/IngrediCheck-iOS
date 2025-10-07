//
//  AverageScansCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 06/10/25.
//

import SwiftUI

struct AvgModel: Identifiable {
    var id = UUID().uuidString
    var value: Int
    var day: String
    
    // Computed property to scale value to a bar height
    var barHeight: CGFloat {
        let maxBarHeight: CGFloat = 50   // Maximum height
        let maxValue: CGFloat = 100      // Maximum value in your data
        return CGFloat(value) / maxValue * maxBarHeight
    }
}

struct AverageScansCard: View {
    
    @State var avgArray: [AvgModel] = [
        AvgModel(value: 100, day: "M"),
        AvgModel(value: 25, day: "T"),
        AvgModel(value: 50, day: "W"),
        AvgModel(value: 75, day: "T"),
        AvgModel(value: 90, day: "F"),
        AvgModel(value: 10, day: "S"),
        AvgModel(value: 100, day: "S")
    ]
    
    @State private var weeklyAverage: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 2) {
                Text(weeklyAverage > 1000 ? "1k+" : weeklyAverage == 1000 ? "1k" : "\(weeklyAverage)")
                    .font(.system(size: 44, weight: .bold))
                    .frame(height: 37.8)
                    .foregroundStyle(.grayScale150)
                
                
                Text("Avg. Scans")
                    .font(ManropeFont.regular.size(10))
                    .foregroundStyle(.grayScale100)
                    .padding(.bottom, 2)
            }
            .padding(.horizontal, 12)
            
            
            VStack(spacing: 4) {
                // Bars + Average Line
                ZStack(alignment: .bottom) {
                    // Weekly Average Line
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.primary300)
                        .frame(width: 140, height: 1.5)
                        .offset(y: -CGFloat(weeklyAverage) / 100 * 50) // move up from bottom
                    
                    // Bars
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(avgArray) { array in
                            RoundedRectangle(cornerRadius: 3)
                                .foregroundStyle(array.value >= weeklyAverage ? .secondary800 : .secondary400)
                                .frame(width: 12, height: array.barHeight)
                        }
                    }
                }
                .frame(height: 50) // ensure ZStack height matches max bar height
                
                // Day Labels
                HStack(spacing: 0) {
                    ForEach(avgArray) { array in
                        Text(array.day)
                            .font(ManropeFont.regular.size(9.2))
                            .foregroundStyle(.grayScale90)
                            .frame(width: 12 + 8, alignment: .center)
                    }
                }
            }
            .padding(.horizontal, 14)

            
        }
        .padding(.vertical, 12)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            Image("avg-scanner")
                .resizable()
                .frame(width: 20, height: 20)
                .padding(12)
            , alignment: .topTrailing
        )
        .onAppear() {
            // calculates the weekly avg from the array values
            weeklyAverage = avgArray.map { $0.value }.reduce(0, +) / avgArray.count
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        AverageScansCard()
    }
}
