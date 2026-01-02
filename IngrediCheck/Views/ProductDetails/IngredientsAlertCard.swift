import SwiftUI

struct IngredientsAlertCard: View {
    @Binding var isExpanded: Bool
    var items: [IngredientAlertItem]
    var status: ProductMatchStatus
    var overallAnalysis: String?  // Overall analysis text from API
    var ingredientRecommendations: [DTO.IngredientRecommendation]?  // To get unmatched ingredient names
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            summaryText
                .padding(.horizontal, 20)
            
            if isExpanded {
                alertItemsList
            } else {
                readMoreRow(text: "Read More")
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
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
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var summaryText: some View {
        buildHighlightedText()
            .font(ManropeFont.regular.size(14))
            .lineSpacing(6)
    }
    
    private func buildHighlightedText() -> Text {
        guard let overallAnalysisText = overallAnalysis, !overallAnalysisText.isEmpty else {
            // Fallback to generic message if no analysis
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
                    statusChip(for: item.status)
                        .padding(.top, index == 0 ? 20 : 0)
                    
                    Text(item.name)
                        .font(NunitoFont.bold.size(16))
                        .foregroundStyle(Color.grayScale150)
                    
                    Text(item.detail)
                        .font(ManropeFont.regular.size(14))
                        .foregroundStyle(.grayScale120)
                        .lineSpacing(4)
                    
                    HStack {
                        avatarStack(for: item)
                        Spacer()
                        HStack(spacing: 12) {
                            Image("thumbsup")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 24)
                                .foregroundStyle(.grayScale130)
                            
                            Image("thumbsdown")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 24)
                                .foregroundStyle(.grayScale130)
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
                    // Create a custom avatar view similar to ChipMemberAvatarView but sized for 32x32
                    MemberAvatarView(memberIdentifier: memberIdentifier)
                        .frame(width: 32, height: 32)
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
}

struct IngredientAlertItem: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let status: IngredientAlertStatus
    let memberIdentifiers: [String]?  // Array of member IDs or ["Everyone"]
}

// Member Avatar View for Ingredients Alert Card (32x32 size)
private struct MemberAvatarView: View {
    @Environment(FamilyStore.self) private var familyStore
    @Environment(WebService.self) private var webService
    
    let memberIdentifier: String // "Everyone" or member UUID string
    
    @State private var avatarImage: UIImage? = nil
    @State private var loadedHash: String? = nil
    
    var body: some View {
        Circle()
            .fill(circleBackgroundColor)
            .frame(width: 32, height: 32)
            .overlay {
                if memberIdentifier == "Everyone" {
                    Image("Everyone")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                } else if let avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                } else if let member = resolvedMember {
                    Text(String(member.name.prefix(1)))
                        .font(NunitoFont.semiBold.size(12))
                        .foregroundStyle(.white)
                }
            }
            .overlay {
                Circle()
                    .stroke(Color.white, lineWidth: 1)
                    .frame(width: 32, height: 32)
            }
            .task(id: memberIdentifier) {
                await loadAvatarIfNeeded()
            }
    }
    
    private var circleBackgroundColor: Color {
        if memberIdentifier == "Everyone" {
            return Color(hex: "#D9D9D9")
        }
        if let member = resolvedMember {
            return Color(hex: member.color)
        }
        return Color(hex: "#D9D9D9")
    }
    
    private var resolvedMember: FamilyMember? {
        guard memberIdentifier != "Everyone",
              let uuid = UUID(uuidString: memberIdentifier),
              let family = familyStore.family else {
            return nil
        }
        
        if uuid == family.selfMember.id {
            return family.selfMember
        }
        return family.otherMembers.first { $0.id == uuid }
    }
    
    @MainActor
    private func loadAvatarIfNeeded() async {
        guard memberIdentifier != "Everyone",
              let member = resolvedMember else {
            avatarImage = nil
            loadedHash = nil
            return
        }
        
        guard let hash = member.imageFileHash, !hash.isEmpty else {
            avatarImage = nil
            loadedHash = nil
            return
        }
        
        if loadedHash == hash, avatarImage != nil {
            return
        }
        
        do {
            let uiImage = try await webService.fetchImage(
                imageLocation: .imageFileHash(hash),
                imageSize: .small
            )
            avatarImage = uiImage
            loadedHash = hash
        } catch {
            // Silently fail - will show fallback
        }
    }
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

