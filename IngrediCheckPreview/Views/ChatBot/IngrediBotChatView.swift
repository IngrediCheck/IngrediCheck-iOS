//
//  IngrediBotChatView.swift
//  IngrediCheckPreview
//
//  Created on 18/11/25.
//

import SwiftUI

struct IngrediBotChatView: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @State private var message: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Image("ai-stars")
                        .resizable()
                        .frame(width: 28, height: 28)
                    
                    Text("Asking with AI suggestions")
                        .font(ManropeFont.medium.size(14))
                        .foregroundStyle(.grayScale110)
                }
                
                Spacer()
                
                Button("Skip") {
                    coordinator.dismissChatBot()
                }
                .font(NunitoFont.semiBold.size(14))
                .foregroundStyle(.grayScale120)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ConversationBubble(
                        text: "I usually avoid processed snacks.",
                        isFirstForSide: true
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
                    ConversationBubble(text: "That’s wonderful! Thanks for sharing. Anything else about your food habits.", isFirstForSide: true)
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
                    message = ""
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
    }
}

private struct ConversationBubble: View {
    var text: String
    var alignment: Alignment = .leading
    var bubbleColor: Color = Color(hex: "75990E")
    var textColor: Color = .white
    var isFirstForSide: Bool = false
    
    var body: some View {
        let isSender = alignment == .trailing
        let baseRadius: CGFloat = 18
        let radii = CornerRadii(
            topLeft: (!isSender && isFirstForSide) ? 0 : baseRadius,
            topRight: baseRadius,
            bottomLeft: isSender ? baseRadius : baseRadius,
            bottomRight: (isSender && isFirstForSide) ? 0 : baseRadius
        )
        
        HStack {
            if alignment == .trailing { Spacer() }
            Text(text)
                .padding(12)
                .font(ManropeFont.regular.size(12))
                .foregroundStyle(textColor)
                .background(
                    RoundedCornerShape(radii: radii)
                        .fill(bubbleColor)
                )
            if alignment == .leading { Spacer() }
        }
    }
}

#Preview("IngrediBotChatView") {
    IngrediBotChatView()
        .environment(AppNavigationCoordinator())
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
