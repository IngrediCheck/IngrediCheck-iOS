//
//  AllergySummaryCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

// MARK: - Food Emoji Mapper

/// Utility to map food item names to their emoji icons from dynamicJsonData
struct FoodEmojiMapper {
    /// Build a dictionary mapping food names to emojis from dynamic steps
    static func buildMapping(from steps: [DynamicStep]) -> [String: String] {
        var mapping: [String: String] = [:]

        for step in steps {
            // Type-1: options array
            if let options = step.content.options {
                for option in options {
                    let normalizedName = option.name.lowercased()
                    if !option.icon.isEmpty && option.icon != "✏️" && option.icon != "✏" {
                        mapping[normalizedName] = option.icon
                    }
                }
            }

            // Type-2: subSteps with options
            if let subSteps = step.content.subSteps {
                for subStep in subSteps {
                    if let options = subStep.options {
                        for option in options {
                            let normalizedName = option.name.lowercased()
                            if !option.icon.isEmpty && option.icon != "✏️" && option.icon != "✏" {
                                mapping[normalizedName] = option.icon
                            }
                        }
                    }
                }
            }

            // Type-3: regions with subRegions
            if let regions = step.content.regions {
                for region in regions {
                    for subRegion in region.subRegions {
                        let normalizedName = subRegion.name.lowercased()
                        if !subRegion.icon.isEmpty && subRegion.icon != "✏️" && subRegion.icon != "✏" {
                            mapping[normalizedName] = subRegion.icon
                        }
                    }
                }
            }
        }

        // Add some common short aliases/variations
        if let peanuts = mapping["peanuts"] { mapping["peanut"] = peanuts }
        if let treeNuts = mapping["tree nuts"] { mapping["nuts"] = treeNuts }
        if let shellfish = mapping["shellfish"] { mapping["crab"] = "🦀"; mapping["shrimp"] = "🦐"; mapping["lobster"] = "🦞" }
        if let fish = mapping["fish"] { mapping["seafood"] = fish }
        if let eggs = mapping["eggs"] { mapping["egg"] = eggs }
        if let dairy = mapping["dairy"] { mapping["milk"] = dairy; mapping["cheese"] = "🧀" }
        if let wheat = mapping["wheat"] { mapping["gluten"] = wheat; mapping["bread"] = "🍞" }

        // Add common items that might appear in summaries
        mapping["red meat"] = "🥩"
        mapping["meat"] = "🥩"
        mapping["chicken"] = "🍗"
        mapping["poultry"] = "🍗"
        mapping["soda"] = "🥤"
        mapping["sugar"] = "🍬"
        mapping["salt"] = "🧂"
        mapping["fried food"] = "🍟"
        mapping["fried foods"] = "🍟"
        mapping["fast food"] = "🍔"
        mapping["processed food"] = "🏭"
        mapping["processed foods"] = "🏭"

        return mapping
    }

    /// Inject emojis into summary text next to matching food names
    static func injectEmojis(in text: String, using mapping: [String: String]) -> String {
        var result = text

        // Sort by length descending to match longer phrases first
        let sortedNames = mapping.keys.sorted { $0.count > $1.count }

        for name in sortedNames {
            guard let emoji = mapping[name] else { continue }

            // Create a case-insensitive regex pattern for the food name
            // Match whole words only (with word boundaries)
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: name))\\b"

            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)

                // Find all matches and replace from end to start to preserve indices
                let matches = regex.matches(in: result, options: [], range: range)

                for match in matches.reversed() {
                    if let swiftRange = Range(match.range, in: result) {
                        let matchedText = String(result[swiftRange])
                        // Only add emoji if not already preceded by an emoji
                        let beforeIndex = swiftRange.lowerBound
                        let hasEmojiBefore: Bool = {
                            guard beforeIndex > result.startIndex else { return false }
                            let prevIndex = result.index(before: beforeIndex)
                            return result[prevIndex].unicodeScalars.first?.properties.isEmoji == true
                        }()

                        if !hasEmojiBefore {
                            result.replaceSubrange(swiftRange, with: "\(emoji) \(matchedText)")
                        }
                    }
                }
            }
        }

        return result
    }

    /// Add MultiColorText markers (*word*) around common highlight phrases
    static func addHighlightMarkers(to text: String) -> String {
        var result = text

        // Phrases to highlight (will appear in lighter color)
        let highlightPhrases = [
            "family",
            "making meal",
            "meal choices",
            "and",
            "for everyone",
            "simpler",
            "safer",
            "choices"
        ]

        // Sort by length descending to match longer phrases first
        let sortedPhrases = highlightPhrases.sorted { $0.count > $1.count }

        for phrase in sortedPhrases {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: phrase))\\b"

            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                let matches = regex.matches(in: result, options: [], range: range)

                for match in matches.reversed() {
                    if let swiftRange = Range(match.range, in: result) {
                        let matchedText = String(result[swiftRange])
                        // Only wrap if not already wrapped in *
                        let beforeIndex = swiftRange.lowerBound
                        let afterIndex = swiftRange.upperBound

                        let hasMarkerBefore = beforeIndex > result.startIndex && result[result.index(before: beforeIndex)] == "*"
                        let hasMarkerAfter = afterIndex < result.endIndex && result[afterIndex] == "*"

                        if !hasMarkerBefore && !hasMarkerAfter {
                            result.replaceSubrange(swiftRange, with: "*\(matchedText)*")
                        }
                    }
                }
            }
        }

        return result
    }
}

// MARK: - AI Summary Card (for UnifiedCanvasView)

/// Full-width summary card shown at top of Food Notes editing view
struct AISummaryCard: View {
    let summary: String
    var dynamicSteps: [DynamicStep] = []

    /// Summary text with emoji icons and highlight markers
    private var formattedSummary: String {
        let mapping = FoodEmojiMapper.buildMapping(from: dynamicSteps)
        let withEmojis = FoodEmojiMapper.injectEmojis(in: summary, using: mapping)
        return FoodEmojiMapper.addHighlightMarkers(to: withEmojis)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // "Summarized with AI" badge
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(.pink))
                Text("Summarized with AI")
                    .font(ManropeFont.medium.size(12))
            }
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "#FB4889"), location: 0),
                        .init(color: Color(hex: "#9A64D4"), location: 0.5048),
                        .init(color: Color(hex: "#0B77FF"), location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(hex: "#FEF2F2"), location: 0),
                                .init(color: Color(hex: "#F9EDF9"), location: 0.5048),
                                .init(color: Color(hex: "#EBF3FE"), location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )

            // Summary text with emojis and multi-color formatting
            MultiColorText(text: "\"\(formattedSummary)\"", font: ManropeFont.bold.size(16))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#EEEEEE"), lineWidth: 0.5)
        )
        .shadow(color: Color(hex: "#ECECEC"), radius: 8)
    }
}

struct MyIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.13143*width, y: height))
        path.addCurve(to: CGPoint(x: 0, y: 0.88265*height), control1: CGPoint(x: 0.05884*width, y: height), control2: CGPoint(x: 0, y: 0.94746*height))
        path.addLine(to: CGPoint(x: 0, y: 0.11735*height))
        path.addCurve(to: CGPoint(x: 0.13143*width, y: 0), control1: CGPoint(x: 0, y: 0.05254*height), control2: CGPoint(x: 0.05884*width, y: 0))
        path.addLine(to: CGPoint(x: 0.86857*width, y: 0))
        path.addCurve(to: CGPoint(x: width, y: 0.11735*height), control1: CGPoint(x: 0.94115*width, y: 0), control2: CGPoint(x: width, y: 0.05254*height))
        path.addLine(to: CGPoint(x: width, y: 0.59843*height))
        path.addCurve(to: CGPoint(x: 0.8531*width, y: 0.72959*height), control1: CGPoint(x: width, y: 0.67087*height), control2: CGPoint(x: 0.93423*width, y: 0.72959*height))
        path.addCurve(to: CGPoint(x: 0.70621*width, y: 0.86075*height), control1: CGPoint(x: 0.77198*width, y: 0.72959*height), control2: CGPoint(x: 0.70621*width, y: 0.78831*height))
        path.addLine(to: CGPoint(x: 0.70621*width, y: 0.8648*height))
        path.addCurve(to: CGPoint(x: 0.55478*width, y: height), control1: CGPoint(x: 0.70621*width, y: 0.93947*height), control2: CGPoint(x: 0.63841*width, y: height))
        path.addLine(to: CGPoint(x: 0.13143*width, y: height))
        path.closeSubpath()
        return path
    }
}

struct AllergySummaryCard: View {
    var summary: String? = nil
    var dynamicSteps: [DynamicStep] = []
    var onTap: (() -> Void)? = nil

    private var emptyStateFormattedText: String {
        formatCardText("\"Add *allergies* or *dietary* needs for your *family* members to make meal *choices* easier for everyone.\"")
    }

    /// Returns true if we should show the empty state (no data yet)
    private var isEmptyState: Bool {
        guard let summary = summary else { return true }
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "No Food Notes yet."
    }

    /// Summary text with emoji icons injected next to food items and highlight markers
    private var summaryWithEmojis: String {
        guard let summary = summary else { return "" }
        let mapping = FoodEmojiMapper.buildMapping(from: dynamicSteps)
        let withEmojis = FoodEmojiMapper.injectEmojis(in: summary, using: mapping)
        return FoodEmojiMapper.addHighlightMarkers(to: withEmojis)
    }

    var body: some View {
        ZStack {
            // Tappable background
            MyIcon()
                .fill(.grayScale10)
                .overlay(
                    MyIcon()
                        .stroke(lineWidth: 0.25)
                        .foregroundStyle(.grayScale60)
                )
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
                .contentShape(MyIcon())
                .onTapGesture {
                    onTap?()
                }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                if isEmptyState {
                    // Empty state: "No Data Yet" badge + placeholder text
                    Text("No Data Yet")
                        .font(ManropeFont.regular.size(8))
                        .foregroundStyle(.grayScale130)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(.grayScale30, in: .capsule)
                        .overlay(
                            Capsule()
                                .stroke(lineWidth: 0.5)
                                .foregroundStyle(.grayScale70)
                        )

                    MultiColorText(text: emptyStateFormattedText)
                        .padding(.trailing, 10)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(6)
                } else {
                    // Has summary: show the AI-generated summary text with emojis
                    MultiColorText(text: "\"\(summaryWithEmojis)\"")
                        .padding(.trailing, 10)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 17)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
            
            // Button overlay - takes priority
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        onTap?()
                    }) {
                        GreenCircle(iconName: "arrow-up-right", iconSize: 20, circleSize: 37)
                            .padding(3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 3)
            .padding(.trailing, 3)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all)
        AllergySummaryCard()
            .frame(width: 171, height: 196, alignment: .center)
    }
}

#Preview("AISummaryCard") {
    AISummaryCard(summary: "Test")
}
