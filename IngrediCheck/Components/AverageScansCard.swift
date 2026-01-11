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
    let maxBarHeight: CGFloat = 50  // Maximum height
    let maxValue: CGFloat = 100   // Maximum value in your data
    return CGFloat(value) / maxValue * maxBarHeight
  }
}
struct AverageScansCard: View {
  @State var avgArray: [AvgModel] = [
    AvgModel(value: 10, day: "M"),
    AvgModel(value: 25, day: "T"),
    AvgModel(value: 35, day: "W"),
    AvgModel(value: 45, day: "T"),
    AvgModel(value: 55, day: "F"),
    AvgModel(value: 5, day: "S"),
    AvgModel(value: 100, day: "S")
  ]
  var playsLaunchAnimation: Bool = false
  @State private var weeklyAverage: Int = 0
  @State private var animatedBarHeights: [CGFloat] = []
  @State private var didPlayLaunchAnimation: Bool = false

  private var targetBarHeights: [CGFloat] {
    avgArray.map { $0.barHeight }
  }

  private func playLaunchBarAnimation() {
    guard !didPlayLaunchAnimation else { return }
    didPlayLaunchAnimation = true

    let count = max(0, avgArray.count)
    let maxBarHeight: CGFloat = 50

    animatedBarHeights = Array(repeating: 0, count: count)

    Task { @MainActor in
      let frameDuration: Double = 1.0 / 30.0

      let phaseStep: Double = Double.pi / 5
      let cyclesPerSecond: Double = 0.5
      let cycleCount: Double = 1
      let totalDuration: Double = cycleCount / cyclesPerSecond
      let frames = Int((totalDuration / frameDuration).rounded(.up))
      let omega: Double = 2 * Double.pi * cyclesPerSecond

      for frame in 0..<frames {
        let t = Double(frame) * frameDuration

        withAnimation(.linear(duration: frameDuration)) {
          animatedBarHeights = (0..<count).map { i in
            let phase = Double(i) * phaseStep
            let s = (sin(omega * t + phase) + 1) / 2
            return CGFloat(s) * maxBarHeight
          }
        }

        try? await Task.sleep(nanoseconds: UInt64(frameDuration * 1_000_000_000))
      }

      withAnimation(.easeOut(duration: 0.5)) {
        animatedBarHeights = targetBarHeights
      }
    }
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
            .frame(width: 140, height: 1.5)
            .offset(y: -CGFloat(weeklyAverage) / 100 * 50) // move up from bottom
          // Bars
          HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(avgArray.enumerated()), id: \.element.id) { index, array in
              let height = (index < animatedBarHeights.count) ? animatedBarHeights[index] : 0
              RoundedRectangle(cornerRadius: 3)
                .foregroundStyle(array.value >= weeklyAverage ? .secondary800 : .secondary400)
                .frame(width: 12, height: height)
            }
          }
        }
        .frame(height: 50, alignment: .bottom) // ensure ZStack height matches max bar height
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
        .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
    )
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

      if animatedBarHeights.isEmpty {
        animatedBarHeights = targetBarHeights
      }

      if playsLaunchAnimation {
        playLaunchBarAnimation()
      }
    }
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .stroke(lineWidth: 0.25)
        .foregroundStyle(.grayScale60)
    )
  }
}
#Preview {
  ZStack {
//    Color.gray.opacity(0.1).ignoresSafeArea()
    AverageScansCard(playsLaunchAnimation: true)
      .frame(width: 200, height: 200)
  }
}
