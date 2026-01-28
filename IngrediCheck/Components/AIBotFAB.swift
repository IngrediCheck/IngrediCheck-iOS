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
        HStack(alignment: .top, spacing: 8) {
            Text("What didn't go well?\nPlease explain.")
                .font(NunitoFont.semiBold.size(15))
                .lineSpacing(5)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Button(action: onDismiss) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 24, height: 24)
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 6,
                topTrailingRadius: 18
            )
            .fill(Color.primary800)
            .shadow(color: Color.black.opacity(0.23), radius: 9, x: 0, y: 4)
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
