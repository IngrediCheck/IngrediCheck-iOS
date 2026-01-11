//
//  FormatedTextCard.swift
//  IngrediCheck
//
//  Created by Gaurav on 09/01/26.
//

import Foundation
func formatCardText(
    _ text: String,
    maxCharsPerLine: Int = 28,
    maxLines: Int = 4
) -> String {

    // NOTE:
    // We intentionally do NOT insert manual "\n" here.
    // SwiftUI should wrap naturally based on the available width.
    // This function focuses on producing a clean, stable string so
    // MultiColorText never renders wrapped lines with leading-space indentation.

    // 1) Trim surrounding quotes and whitespace/newlines.
    let trimmed = text
        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        .trimmingCharacters(in: .whitespacesAndNewlines)

    // 2) Collapse all internal whitespace (including newlines/tabs) to a single space.
    let collapsed = trimmed
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")

    // 3) Preserve '*' markers for MultiColorText coloring, but ensure that
    // any whitespace AFTER a closing '*' is moved INSIDE the highlighted segment.
    // This prevents wrapped lines from starting with a space when SwiftUI wraps
    // at a boundary between Text segments.
    var result = ""
    result.reserveCapacity(collapsed.count)

    let chars = Array(collapsed)
    var i = 0
    var isInsideHighlight = false

    while i < chars.count {
        let ch = chars[i]

        if ch == "*" {
            if isInsideHighlight {
                // Closing '*': move any following spaces inside before closing.
                var j = i + 1
                var sawWhitespace = false
                while j < chars.count, chars[j].isWhitespace {
                    sawWhitespace = true
                    j += 1
                }

                if sawWhitespace {
                    result.append(" ")
                    result.append("*")
                    i = j
                } else {
                    result.append("*")
                    i += 1
                }

                isInsideHighlight = false
                continue
            } else {
                // Opening '*'
                isInsideHighlight = true
                result.append("*")
                i += 1
                continue
            }
        }

        result.append(ch)
        i += 1
    }

    // 4) Final cleanup: trim and collapse repeated spaces WITHOUT splitting tokens.
    // Using components(separatedBy:) here would break '*' markers (e.g. "*or *dietary").
    var cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
    while cleaned.contains("  ") {
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
    }
    return cleaned
}
