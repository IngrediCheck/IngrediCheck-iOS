//
//  AIBotFAB.swift
//  IngrediCheck
//
//  Floating Action Button for AIBot access with optional feedback prompt bubble.
//

import SwiftUI

struct AIBotFAB: View {
    let onTap: () -> Void
    var showPromptBubble: Bool = false
    var onPromptTap: (() -> Void)? = nil
    var onPromptDismiss: (() -> Void)? = nil

    var body: some View {
        HStack {
            
            Spacer()
            // Prompt bubble (appears above/left of FAB)
            if showPromptBubble {
                FeedbackPromptBubble(
                    onTap: { onPromptTap?() },
                    onDismiss: { onPromptDismiss?() }
                )
                .transition(.scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity))
                .offset(y: -40)
            }

            // FAB button
            Button(action: onTap) {
                Image("aibot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct FeedbackPromptBubble: View {
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("What didn't go well?\nPlease explain")
                .font(ManropeFont.medium.size(13))
                .foregroundStyle(.grayScale150)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Button(action: onDismiss) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.13))
                        .frame(width: 22, height: 22)
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .offset(y: -8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    VStack(alignment: .trailing) {
        Spacer()
        HStack {
            Spacer()
            AIBotFAB(
                onTap: {},
                showPromptBubble: true,
                onPromptTap: {},
                onPromptDismiss: {}
            )
            .padding(.trailing, 20)
//            .padding(.bottom, 100)
        }
    }
    .background(Color.gray.opacity(0.2))
}
