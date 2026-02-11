import SwiftUI

struct IngredientDetailsView: View {
    let paragraphs: [IngredientParagraph]
    @Binding var activeHighlight: IngredientHighlight?
    let highlightColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(paragraphs) { paragraph in
                VStack(alignment: .leading, spacing: 6) {
                    if let title = paragraph.title {
                        Text(title)
                            .font(NunitoFont.bold.size(15))
                            .foregroundStyle(.grayScale150)
                    }

                    HighlightableParagraph(
                        paragraph: paragraph,
                        activeHighlight: $activeHighlight,
                        highlightColor: highlightColor
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct HighlightableParagraph: View {
    let paragraph: IngredientParagraph
    @Binding var activeHighlight: IngredientHighlight?
    let highlightColor: Color
    
    private var segments: [IngredientSegment] {
        segmentedText(paragraph.body, highlights: paragraph.highlights)
    }
    
    var body: some View {
        Text(buildAttributedString())
            .font(ManropeFont.regular.size(14))
            .foregroundStyle(.grayScale120)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "ingredihighlight",
                   let indexStr = url.host(),
                   let index = Int(indexStr),
                   index < paragraph.highlights.count {
                    let highlight = paragraph.highlights[index]
                    if activeHighlight?.id == highlight.id {
                        activeHighlight = nil
                    } else {
                        activeHighlight = highlight
                    }
                }
                return .handled
            })
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()
        for segment in segments {
            switch segment {
            case .text(let value):
                result += AttributedString(value)
            case .highlight(let value, let highlight):
                var attr = AttributedString(value)
                attr.font = ManropeFont.semiBold.size(14)
                attr.foregroundColor = highlight.color
                attr.underlineStyle = .init(pattern: .solid, color: .clear)
                if let idx = paragraph.highlights.firstIndex(where: { $0.phrase.lowercased() == highlight.phrase.lowercased() }),
                   let url = URL(string: "ingredihighlight://\(idx)") {
                    attr.link = url
                }
                result += attr
            case .lineBreak:
                result += AttributedString("\n")
            }
        }
        return result
    }
}

struct IngredientTooltipView: View {
    let highlight: IngredientHighlight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(highlight.phrase)
                .font(NunitoFont.bold.size(13))
                .foregroundStyle(.grayScale150)
            
            Text(highlight.reason)
                .font(ManropeFont.regular.size(12))
                .foregroundStyle(.grayScale120)
                .lineSpacing(3)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
        )
        .padding(.top, 8)
    }
}

// MARK: - Highlight Support

enum IngredientSegment {
    case text(String)
    case highlight(String, IngredientHighlight)
    case lineBreak
}

struct IngredientParagraph: Identifiable {
    let id = UUID()
    let title: String?
    let body: String
    let highlights: [IngredientHighlight]
}

struct IngredientHighlight: Identifiable, Equatable {
    let id = UUID()
    let phrase: String
    let reason: String
    let color: Color  // Per-highlight color based on safety recommendation

    init(phrase: String, reason: String, color: Color = .red) {
        self.phrase = phrase
        self.reason = reason
        self.color = color
    }
}

private func segmentedText(_ text: String, highlights: [IngredientHighlight]) -> [IngredientSegment] {
    let lowercased = text.lowercased()
    var matches: [(Range<String.Index>, IngredientHighlight)] = []
    
    for highlight in highlights {
        let searchPhrase = highlight.phrase.lowercased()
        var searchStartIndex = lowercased.startIndex

        // Find ALL occurrences of this highlight phrase
        while let range = lowercased.range(of: searchPhrase, range: searchStartIndex..<lowercased.endIndex) {
            matches.append((range, highlight))
            searchStartIndex = range.upperBound
        }
    }
    
    matches.sort { $0.0.lowerBound < $1.0.lowerBound }
    
    var segments: [IngredientSegment] = []
    var currentIndex = text.startIndex
    
    func appendNormal(_ substring: Substring) {
        var buffer = ""
        for char in substring {
            if char == "\n" {
                if !buffer.isEmpty {
                    segments.append(.text(buffer))
                    buffer = ""
                }
                segments.append(.lineBreak)
            } else {
                buffer.append(char)
            }
        }
        if !buffer.isEmpty {
            segments.append(.text(buffer))
        }
    }
    
    for (range, highlight) in matches {
        if range.lowerBound > currentIndex {
            appendNormal(text[currentIndex..<range.lowerBound])
        }
        
        let highlightedSubstring = text[range]
        segments.append(.highlight(String(highlightedSubstring), highlight))
        currentIndex = range.upperBound
    }
    
    if currentIndex < text.endIndex {
        appendNormal(text[currentIndex..<text.endIndex])
    }
    
    return segments
}

