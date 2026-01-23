import SwiftUI

struct IngredientsAlertCard: View {
    @Environment(FamilyStore.self) private var familyStore

    @Binding var isExpanded: Bool
    var items: [IngredientAlertItem]
    var status: ProductMatchStatus
    var overallAnalysis: String?  // Overall analysis text from API
    var ingredientRecommendations: [DTO.IngredientRecommendation]?  // To get unmatched ingredient names
    var onFeedback: ((IngredientAlertItem, String) -> Void)? = nil // Item, Vote ("up", "down")
    var productVote: DTO.Vote? = nil  // Current product feedback vote
    var onProductFeedback: ((String) -> Void)? = nil // Product feedback callback ("up", "down")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            summaryText
                .padding(.horizontal, 20)
            
            if status != .matched {
                if isExpanded {
                    alertItemsList
                } else {
                    readMoreRow(text: "Read More")
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            } else {
                // Add bottom padding for matched state since there's no read more row
                Color.clear.frame(height: 0).padding(.bottom, 20)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(status.alertCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard status != .matched else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
    
    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)

                Text(status.alertTitle)
                    .font(NunitoFont.bold.size(12))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(status.color, in: Capsule())

            Spacer(minLength: 0)

            // Product feedback buttons (thumb up/down) on the right
            if let onProductFeedback {
                HStack(spacing: 12) {
                    FeedbackButton(
                        type: .up,
                        isSelected: productVote?.value == "up",
                        style: .whiteBoxed
                    ) {
                        onProductFeedback("up")
                    }

                    FeedbackButton(
                        type: .down,
                        isSelected: productVote?.value == "down",
                        style: .whiteBoxed
                    ) {
                        onProductFeedback("down")
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var summaryText: some View {
        buildHighlightedText()
            .font(ManropeFont.regular.size(14))
            .lineSpacing(6)
            .lineLimit(4)
    }
    
    private func buildHighlightedText() -> Text {
        guard let overallAnalysisText = overallAnalysis, !overallAnalysisText.isEmpty else {
            // Fallback to generic message if no analysis
            if status == .matched {
                return Text("This product aligns with your dietary preferences.")
                    .foregroundStyle(.grayScale150)
            }
            return Text("This product contains ingredients that may not be suitable for your family's dietary preferences.")
                .foregroundStyle(.grayScale150)
        }
        
        // Get list of unmatched ingredient names
        let unmatchedIngredients = ingredientRecommendations?
            .filter { $0.safetyRecommendation == .definitelyUnsafe }
            .map { $0.ingredientName }
            ?? []
        
        if unmatchedIngredients.isEmpty {
            // No ingredients to highlight, return plain text
            return Text(overallAnalysisText).foregroundStyle(.grayScale150)
        }
        
        // Find all ranges of ingredients to highlight
        var highlightRanges: [(range: Range<String.Index>, ingredient: String)] = []
        
        for ingredient in unmatchedIngredients {
            var searchStartIndex = overallAnalysisText.startIndex
            
            while searchStartIndex < overallAnalysisText.endIndex,
                  let range = overallAnalysisText.range(of: ingredient, options: .caseInsensitive, range: searchStartIndex..<overallAnalysisText.endIndex) {
                highlightRanges.append((range: range, ingredient: ingredient))
                searchStartIndex = range.upperBound
            }
        }
        
        // Sort ranges by start position
        highlightRanges.sort { $0.range.lowerBound < $1.range.lowerBound }
        
        // Merge overlapping ranges (if any)
        var mergedRanges: [Range<String.Index>] = []
        for (range, _) in highlightRanges {
            if let lastRange = mergedRanges.last, lastRange.overlaps(range) || lastRange.upperBound == range.lowerBound {
                // Extend the last range
                mergedRanges[mergedRanges.count - 1] = lastRange.lowerBound..<max(lastRange.upperBound, range.upperBound)
            } else {
                mergedRanges.append(range)
            }
        }
        
        // Build attributed text
        var result = Text("")
        var currentIndex = overallAnalysisText.startIndex
        
        for range in mergedRanges {
            // Add text before the highlighted range
            if currentIndex < range.lowerBound {
                let plainText = String(overallAnalysisText[currentIndex..<range.lowerBound])
                result = result + Text(plainText).foregroundStyle(.grayScale150)
            }
            
            // Add highlighted text
            let highlightedText = String(overallAnalysisText[range])
            result = result + Text(highlightedText)
                .foregroundStyle(status.color)
                .fontWeight(.bold)
            
            currentIndex = range.upperBound
        }
        
        // Add remaining text
        if currentIndex < overallAnalysisText.endIndex {
            let remainingText = String(overallAnalysisText[currentIndex..<overallAnalysisText.endIndex])
            result = result + Text(remainingText).foregroundStyle(.grayScale150)
        }
        
        return result
    }
    
    private func readMoreRow(text: String) -> some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Text(text)
                    .font(NunitoFont.bold.size(15))
                    .foregroundStyle(status.color)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(status.color)
            }
        }
    }
    
    private var alertItemsList: some View {
        VStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 12) {
                    // Ingredient name with status badge on the right
                    HStack(spacing: 8) {
                        Text(item.name)
                            .font(NunitoFont.bold.size(16))
                            .foregroundStyle(Color.grayScale150)
                        Spacer()
                        statusChip(for: item.status)
                    }
                    .padding(.top, index == 0 ? 20 : 0)

                    Text(item.detail)
                        .font(ManropeFont.regular.size(14))
                        .foregroundStyle(.grayScale120)
                        .lineSpacing(4)

                    HStack {
                        avatarStack(for: item)
                        Spacer()
                        HStack(spacing: 12) {
                            FeedbackButton(
                                type: .up,
                                isSelected: item.vote?.value == "up",
                                style: .boxed
                            ) {
                                onFeedback?(item, "up")
                            }

                            FeedbackButton(
                                type: .down,
                                isSelected: item.vote?.value == "down",
                                style: .boxed
                            ) {
                                onFeedback?(item, "down")
                            }
                        }
                    }
                }
                .padding(.vertical, 12)

                if index != items.count - 1 {
                    Divider()
                }
            }

            readMoreRow(text: "Read Less")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: "#D8D8D8").opacity(0.25), radius: 9.8, y: 6)
        .padding(.top, 4)
    }
    
    private func statusChip(for status: IngredientAlertStatus) -> some View {
        Text(status.title)
            .font(NunitoFont.bold.size(12))
            .foregroundStyle(status.foregroundColor)
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .background(status.backgroundColor, in: Capsule())
    }
    
    private func avatarStack(for item: IngredientAlertItem) -> some View {
        HStack(spacing: -8) {
            if let memberIdentifiers = item.memberIdentifiers, !memberIdentifiers.isEmpty {
                ForEach(Array(memberIdentifiers.prefix(5)), id: \.self) { memberIdentifier in
                    if memberIdentifier == "Family" {
                        // Special "Everyone" avatar
                        Circle()
                            .fill(Color(hex: "#D9D9D9"))
                            .frame(width: 32, height: 32)
                            .overlay {
                                Image("family")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 30, height: 30)
                                    .clipShape(Circle())
                            }
                            .overlay {
                                Circle().stroke(Color.white, lineWidth: 1)
                            }
                    } else if let member = resolveMember(from: memberIdentifier) {
                        // Use centralized MemberAvatar component
                        MemberAvatar.custom(member: member, size: 32, imagePadding: 0)
                    }
                }
            } else {
                // Fallback: show placeholder if no member identifiers
                ForEach(["image-bg1", "image-bg2", "image-bg3"], id: \.self) { name in
                    Image(name)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Resolves a FamilyMember from a member identifier string
    private func resolveMember(from identifier: String) -> FamilyMember? {
        guard let uuid = UUID(uuidString: identifier),
              let family = familyStore.family else {
            return nil
        }

        if uuid == family.selfMember.id {
            return family.selfMember
        }
        return family.otherMembers.first { $0.id == uuid }
    }
}

struct IngredientAlertItem: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let status: IngredientAlertStatus
    let memberIdentifiers: [String]?  // Array of member IDs or ["Family"]
    let vote: DTO.Vote?
    let rawIngredientName: String? // Actual ingredient name from API if available
}

enum IngredientAlertStatus {
    case unmatched
    case uncertain
    
    var title: String {
        switch self {
        case .unmatched: return "Unmatched"
        case .uncertain: return "Uncertain"
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .unmatched: return Color(hex: "#FF4E50")
        case .uncertain: return Color(hex: "#E9A600")
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .unmatched: return Color(hex: "#FFE3E2")
        case .uncertain: return Color(hex: "#FFF4DB")
        }
    }
}

