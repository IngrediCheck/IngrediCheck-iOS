import SwiftUI

struct IngredientDetailsView: View {
    let paragraphs: [IngredientParagraph]
    @Binding var activeHighlight: IngredientHighlight?
    
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
                        activeHighlight: $activeHighlight
                    )
                }
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottomLeading) {
            if let highlight = activeHighlight {
                IngredientTooltipView(highlight: highlight)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.top, 12)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: activeHighlight)
        .onTapGesture {
            activeHighlight = nil
        }
    }
}

struct HighlightableParagraph: View {
    let paragraph: IngredientParagraph
    @Binding var activeHighlight: IngredientHighlight?
    
    private var segments: [IngredientSegment] {
        segmentedText(paragraph.body, highlights: paragraph.highlights)
    }
    
    var body: some View {
        FlowLayout(horizontalSpacing: 0, verticalSpacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let value):
                    Text(value)
                        .font(ManropeFont.regular.size(14))
                        .foregroundStyle(.grayScale120)
                case .highlight(let value, let highlight):
                    Button {
                        if activeHighlight?.id == highlight.id {
                            activeHighlight = nil
                        } else {
                            activeHighlight = highlight
                        }
                    } label: {
                        Text(value)
                            .font(ManropeFont.semiBold.size(14))
                            .foregroundStyle(Color(hex: "#FF4E50"))
                    }
                    .buttonStyle(.plain)
                case .lineBreak:
                    Color.clear
                        .frame(width: 0, height: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
}

private func segmentedText(_ text: String, highlights: [IngredientHighlight]) -> [IngredientSegment] {
    let lowercased = text.lowercased()
    var matches: [(Range<String.Index>, IngredientHighlight)] = []
    
    for highlight in highlights {
        if let range = lowercased.range(of: highlight.phrase.lowercased()) {
            matches.append((range, highlight))
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

