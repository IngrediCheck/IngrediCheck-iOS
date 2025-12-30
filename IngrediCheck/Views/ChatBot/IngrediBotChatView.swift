//
//  IngrediBotChatView.swift
//  IngrediCheckPreview
//
//  Created on 18/11/25.
//
//

import SwiftUI

struct IngrediBotChatView: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @State private var message: String = ""
    var onDismiss: (() -> Void)? = nil
    @State private var isBotThinking: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                
                Spacer()
                
                VStack(alignment: .center, spacing: 5) {
                    Image("ai-magic")
                        .resizable()
                        .frame(width: 28, height: 28)
                    
                    Text("Asking with AI suggestions")
                        .font(ManropeFont.medium.size(14))
                        .foregroundStyle(.grayScale110)
                }
                
                Spacer()
                
            }
            .padding(.top, 16)
            .overlay(alignment: .topTrailing) {
                Button("Skip") {
                    if let onDismiss {
                        onDismiss()
                    } else {
                        coordinator.dismissChatBot()
                    }
                }
                .font(NunitoFont.semiBold.size(14))
                .foregroundStyle(.grayScale120)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ConversationBubble(
                        text: "I usually avoid processed snacks.",
                        isFirstForSide: true,
                        leadingIconName: "ingrediBot"
                    )
                    ConversationBubble(
                        text: "What else did you want to avoid?",
                        isFirstForSide: false
                    )
                    ConversationBubble(
                        text: "Yeah, I follow a mix of ayurvedic and seasonal eating.",
                        alignment: .trailing,
                        bubbleColor: Color(hex: "F4F4F4"),
                        textColor: .grayScale140,
                        isFirstForSide: true
                    )
                    ConversationBubble(text: "That’s wonderful! Thanks for sharing. Anything else about your food habits.",
                                       isFirstForSide: true,
                                       leadingIconName: "ingrediBot"
                    )
                    ConversationBubble(
                        text: "Thanks! I also react to whey and casein so I keep dairy limited.",
                        alignment: .trailing,
                        bubbleColor: Color(hex: "F4F4F4"),
                        textColor: .grayScale140,
                        isFirstForSide: true
                    )
                    ConversationBubble(
                        text: "Got it. I'll mark dairy-heavy items as watchouts and keep you updated.\nWould you like me to flag plant-based alternatives that fit your IngrediFam?",
                        isFirstForSide: true,
                        leadingIconName: "ingrediBot"
                    )
                    ConversationBubble(
                        text: "Yes please. Organic when possible, and avoid artificial sweeteners because my son gets headaches.",
                        alignment: .trailing,
                        bubbleColor: Color(hex: "F4F4F4"),
                        textColor: .grayScale140,
                        isFirstForSide: true
                    )
                    ConversationBubble(
                        text: "Perfect! I’ll look for organic-friendly snacks and skip anything with sucralose, aspartame, or excessive additives.\nNeed me to add reminders before grocery runs?",
                        isFirstForSide: true,
                        leadingIconName: "ingrediBot"
                    )
                    ConversationBubble(
                        text: "That would be awesome. Saturdays work best and I usually shop in the morning.",
                        alignment: .trailing,
                        bubbleColor: Color(hex: "F4F4F4"),
                        textColor: .grayScale140,
                        isFirstForSide: true
                    )
                    ConversationBubble(
                        text: "Great! I’ve queued a Saturday morning prep reminder and saved your updated preferences.\nAnything else you’d like help with right now?",
                        isFirstForSide: true,
                        leadingIconName: "ingrediBot"
                    )
                    
                    if isBotThinking {
                        TypingBubble(side: .bot)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                TextField("\"Type your answer...\"", text: $message, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.2))
                    )
                
                Button {
                    let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        message = ""
                    }
                    // Navigate directly to the next screen (home) instead of DetailedAISummary
                    if let onDismiss {
                        onDismiss()
                    } else {
                        coordinator.dismissChatBot()
                    }
                    coordinator.showCanvas(.home)
                    coordinator.navigateInBottomSheet(.homeDefault)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.white)
                        .padding()
                        .background(
                            Circle().fill(
                                LinearGradient(
                                    colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .shadow(.inner(color: Color(hex: "EDEDED").opacity(0.25), radius: 7.5, x: 2, y: 9))
                                .shadow(.inner(color: Color(hex: "72930A"), radius: 5.7, x: 0, y: 4))
                                .shadow(
                                    .drop(color: Color(hex: "C5C5C5").opacity(0.57), radius: 11, x: 0, y: 4)
                                )
                            )
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .onChange(of: message) {
            withAnimation(.easeInOut(duration: 0.2)) {
                // Keep future hook for showing typing previews or suggestions.
            }
        }
    }
}

private struct ConversationBubble: View {
    var text: String
    var alignment: Alignment = .leading
    var bubbleColor: Color = Color(hex: "75990E")
    var textColor: Color = .white
    var isFirstForSide: Bool = false
    var leadingIconName: String?
    
    var body: some View {
        let isSender = alignment == .trailing
        let baseRadius: CGFloat = 18
        let radii = CornerRadii(
            topLeft: (!isSender && isFirstForSide) ? 0 : baseRadius,
            topRight: baseRadius,
            bottomLeft: isSender ? baseRadius : baseRadius,
            bottomRight: (isSender && isFirstForSide) ? 0 : baseRadius
        )
        
        HStack(alignment: .top, spacing: 8) {
            if alignment == .trailing { Spacer() }
            
            if alignment == .leading {
                if let iconName = leadingIconName {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                } else {
                    Color.clear
                        .frame(width: 32, height: 32)
                }
            }
            
            Text(text)
                .padding(12)
                .font(ManropeFont.regular.size(14))
                .foregroundStyle(textColor)
                .background(
                    RoundedCornerShape(radii: radii)
                        .fill(bubbleColor)
                )
            
            if alignment == .leading { Spacer() }
        }
    }
}

private struct TypingBubble: View {
    enum Side {
        case bot
        case user
    }
    
    var side: Side
    @State private var animate = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if side == .bot {
                Image("ingrediBot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
            } else {
                Spacer()
            }
            
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animate ? 1 : 0.6)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: animate
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(side == .bot ? Color(hex: "F4F4F4") : Color(hex: "75990E").opacity(0.2))
            )
            
            if side == .bot {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: side == .bot ? .leading : .trailing)
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }
}

#Preview("IngrediBotChatView") {
    NavigationStack {
        IngrediBotChatView()
            .environment(AppNavigationCoordinator())
    }
}

#Preview("ConversationBubble") {
    ConversationBubble(text: "Hello!!", isFirstForSide: true)
}

private struct CornerRadii {
    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomLeft: CGFloat
    var bottomRight: CGFloat
}

private struct RoundedCornerShape: Shape {
    var radii: CornerRadii
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let tl = max(0, min(min(rect.width, rect.height)/2, radii.topLeft))
        let tr = max(0, min(min(rect.width, rect.height)/2, radii.topRight))
        let bl = max(0, min(min(rect.width, rect.height)/2, radii.bottomLeft))
        let br = max(0, min(min(rect.width, rect.height)/2, radii.bottomRight))
        
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                    radius: tr,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(0),
                    clockwise: false)
        
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                    radius: br,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false)
        
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                    radius: bl,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false)
        
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                    radius: tl,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false)
        
        path.closeSubpath()
        return path
    }
}
