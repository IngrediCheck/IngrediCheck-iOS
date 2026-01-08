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
        AvgModel(value: 10, day: "M"),
        AvgModel(value: 20, day: "T"),
        AvgModel(value: 0, day: "W"),
        AvgModel(value: 10, day: "T"),
        AvgModel(value: 10, day: "F"),
        AvgModel(value: 10, day: "S"),
        AvgModel(value:10, day: "S")
    ]

    private var weeklyAverage: Int {
        guard !avgArray.isEmpty else { return 0 }
        return avgArray.map { $0.value }.reduce(0, +) / avgArray.count
    }

    private let chartHeight: CGFloat = 50
    private let barWidth: CGFloat = 12
    private let barSpacing: CGFloat = 8
    private let chartSideSpacing: CGFloat = 4

    private var chartWidth: CGFloat {
        let count = max(1, avgArray.count)
        let barsTotal = CGFloat(count) * barWidth + CGFloat(max(0, count - 1)) * barSpacing
        return barsTotal + (chartSideSpacing * 2)
    }

    private var chartMaxValue: CGFloat {
        let maxDataValue = avgArray.map { $0.value }.max() ?? 0
        return CGFloat(max(1, max(maxDataValue, weeklyAverage)))
    }

    private func scaledHeight(for value: Int) -> CGFloat {
        CGFloat(value) / chartMaxValue * chartHeight
    }
    
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
                        .frame(width: chartWidth, height: 1.5)
                        .offset(y: -CGFloat(weeklyAverage) / chartMaxValue * chartHeight) // move up from bottom
                    
                    // Bars
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(avgArray) { array in
                            RoundedRectangle(cornerRadius: 3)
                                .foregroundStyle(array.value >= weeklyAverage ? .secondary800 : .secondary400)
                                .frame(width: barWidth, height: scaledHeight(for: array.value))
                        }
                    }
                }
                .frame(height: chartHeight) // ensure ZStack height matches max bar height
                
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .foregroundStyle(.white)
                .shadow(color: Color(hex: "#E6F6CD"
                                    ), radius: 9, x: 0, y: 0)
        )
        
        .overlay(
            Image("avg-scanner")
                .resizable()
                .frame(width: 20, height: 20)
                .padding(12)
            , alignment: .topTrailing
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(lineWidth: 0.25)
                .foregroundStyle(.grayScale60)
        )
    }
}

#Preview {
    ZStack {
//        Color.gray.opacity(0.1).ignoresSafeArea()
        AverageScansCard()
    }
}
