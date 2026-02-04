//
//  ChatBubble.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 06/10/25.
//

import SwiftUI

enum ChatRole {
    case user
    case assistant
}
    

struct ChatBubble: View {
    // Message content
    var text: String = "Would you like to explore a specific area next?"
    
    // Sender role for alignment (assistant on left, user on right)
    var role: ChatRole = .assistant
    
    // Toggle to switch between the two visual variants shown in the screenshots
    // Variant A: Text-only bubble
    // Variant B: Text + inner white-outlined pill action
    var useAlternateStyle: Bool = false
    
    // Optional inner pill title used in the alternate style (screenshot 2)
    var pillTitle: String = "Added under Allergies"
    
    // Tracks measured width of the green bubble so the below row aligns with it
    @State private var measuredBubbleWidth: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .top) {
            if role == .assistant { contentColumn; Spacer(minLength: 40) }
            else { Spacer(minLength: 40); contentColumn }
        }
    }
    
    // MARK: - Bubble + Below Content
    private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            bubble
            if useAlternateStyle { feedbackRow } else { quickActions }
        }
        .onPreferenceChange(BubbleWidthKey.self) { measuredBubbleWidth = $0 }
    }
    
    // MARK: - Bubble
    private var bubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(ManropeFont.regular.size(12))
                .foregroundStyle(.grayScale10)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
            
            if useAlternateStyle {
                HStack(spacing: 8) {
                    Text(pillTitle)
                        .font(ManropeFont.semiBold.size(10))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.grayScale10)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .stroke(.grayScale10, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .foregroundStyle(.primary800)
        )
        // Measure the bubble width for aligning the below row
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: BubbleWidthKey.self, value: geo.size.width)
            }
        )
    }
    
    // MARK: - Below Content: Variant A (Quick actions)
    private var quickActions: some View {
        let items = [
            "What You Eat",
            "What You Avoid",
            "What You Care About",
            "Your Lifestyle"
        ]
        
        return FlowLayout(horizontalSpacing: 8, verticalSpacing: 12)  {
            ForEach(items, id: \.self) { ele in
                Text(ele)
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale140)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .stroke(lineWidth: 1)
                            .foregroundStyle(
                                LinearGradient(colors: [Color(hex: "7BA10F"), Color(hex: "B1D26C")], startPoint: .leading, endPoint: .trailing)
                            )
                    )
            }
        }
    }
    
    // MARK: - Below Content: Variant B (Copy / Like / Dislike)
    private var feedbackRow: some View {
        HStack {
            
            HStack(spacing: 8) {
                Image("copy")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.grayScale120)
                Microcopy.text(Microcopy.Key.Chat.ctaCopyText)
                    .font(ManropeFont.regular.size(12))
                    .foregroundStyle(Color(hex: "#7F7F7F"))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(lineWidth: 0.5)
                    .foregroundStyle(.grayScale60)
            )
            
            Spacer()
            
            // Thumbs
            HStack(spacing: 10) {
                Circle()
                    .foregroundStyle(.grayScale10)
                    .frame(width: 36, height: 36)
                    .shadow(color: Color(hex: "FBFBFB"), radius: 9, x: 0, y: 0)
                    .overlay(
                        Image("like")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.grayScale120)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.grayScale80, lineWidth: 0.5)
                            .frame(width: 32, height: 28)
                    )
                
                Circle()
                    .foregroundStyle(.grayScale10)
                    .frame(width: 36, height: 36)
                    .shadow(color: Color(hex: "FBFBFB"), radius: 9, x: 0, y: 0)
                    .overlay(
                        Image("dislike")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.grayScale120)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.grayScale80, lineWidth: 0.5)
                            .frame(width: 32, height: 28)
                    )
            }
        }
        // Constrain to the bubble width so content remains aligned regardless of text size
        .frame(width: measuredBubbleWidth > 0 ? measuredBubbleWidth : nil, alignment: .leading)
    }
}

// PreferenceKey to capture rendered width of the bubble
private struct BubbleWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        // Variant A
        ChatBubble(text: "Would you like to explore a specific area next?",
                   role: .assistant,
                   useAlternateStyle: false)
        // Variant B
        ChatBubble(text: "Got it 👍 Keeping things natural and fresh,  noted!",
                   role: .assistant,
                   useAlternateStyle: true,
                   pillTitle: "Added under Allergies")
    }
    .padding()
}
