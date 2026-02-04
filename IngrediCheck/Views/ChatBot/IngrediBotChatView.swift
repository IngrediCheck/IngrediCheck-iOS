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
    @Environment(AppState.self) private var appState
    @Environment(WebService.self) private var webService
    @Environment(ChatStore.self) private var chatStore

    // Optional parameters for context-aware chat
    var scanId: String? = nil
    var analysisId: String? = nil
    var ingredientName: String? = nil
    var feedbackId: String? = nil  // For feedback follow-up context
    var contextKeyOverride: String? = nil  // Explicit context key (e.g., "food_notes" from editing screen)

    var onDismiss: (() -> Void)? = nil

    @State private var message: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var conversationId: String? = nil
    @State private var visibleMessageIds: Set<String> = []
    @State private var isStreaming: Bool = false
    @State private var currentTurnId: String? = nil
    @State private var isLoadingHistory: Bool = false
    @State private var errorMessage: String? = nil
    @FocusState private var isInputFocused: Bool

    /// Check if user is in onboarding flow (not on home or summary screens)
    private var isOnboardingFlow: Bool {
        coordinator.currentCanvasRoute != .home &&
        coordinator.currentCanvasRoute != .summaryJustMe &&
        coordinator.currentCanvasRoute != .summaryAddFamily
    }

    private var contextKey: String {
        if let feedbackId { return "feedback:\(feedbackId)" }
        if let scanId { return "product_scan:\(scanId)" }
        // Check explicit context override first (e.g., "food_notes" from editing screen)
        if let contextKeyOverride { return contextKeyOverride }
        let isFoodNotes = coordinator.currentCanvasRoute == .summaryJustMe ||
                          coordinator.currentCanvasRoute == .summaryAddFamily ||
                          coordinator.currentCanvasRoute == .welcomeToYourFamily ||
                          isOnboardingFlow
        if isFoodNotes { return "food_notes" }
        return "home"
    }

    private func syncToStore() {
        chatStore.update(for: contextKey) {
            $0.messages = messages
            $0.conversationId = conversationId
            $0.visibleMessageIds = visibleMessageIds
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
//            HStack {
//                
//                Spacer()
//                
//                VStack(alignment: .center, spacing: 5) {
//                    Image("ai-magic")
//                        .resizable()
//                        .frame(width: 28, height: 28)
//                    
//                    Text("Asking with AI suggestions")
//                        .font(ManropeFont.medium.size(14))
//                        .foregroundStyle(.grayScale110)
//                }
//                
//                Spacer()
//                
//            }
//            .padding(.top, 16)
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if isLoadingHistory {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                        }
                        
                        // Display messages with animation
                        ForEach(messages) { msg in
                            if visibleMessageIds.contains(msg.id) {
                                ConversationBubble(
                                    text: msg.text,
                                    alignment: msg.isUser ? .trailing : .leading,
                                    bubbleColor: msg.isUser ? Color(hex: "F4F4F4") : Color(hex: "75990E"),
                                    textColor: msg.isUser ? .grayScale140 : .white,
                                    isFirstForSide: false,
                                    leadingIconName: msg.isUser ? nil : "ingrediBot"
                                )
                                .id(msg.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8, anchor: msg.isUser ? .bottomTrailing : .bottomLeading)
                                        .combined(with: .opacity)
                                        .combined(with: .offset(y: 20)),
                                    removal: .opacity
                                ))
                            }
                        }
                        
                        // Show typing indicator when streaming
                        if isStreaming {
                            TypingBubble(side: .bot)
                        }

                        // Bottom anchor for reliable scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottomAnchor")

                        // Show error message if any
                        if errorMessage != nil {
                            ConversationBubble(
                                text: Microcopy.string(Microcopy.Key.Errors.genericToast),
                                isFirstForSide: true,
                                leadingIconName: "ingrediBot"
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Dismiss keyboard when tapping on chat area
                        isInputFocused = false
                    }
                }
                .onChange(of: messages.count) { _ in
                    // Scroll to bottom when new messages arrive
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isStreaming) { streaming in
                    // Scroll to show typing indicator when streaming starts
                    if streaming {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo("bottomAnchor", anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: visibleMessageIds.count) { _ in
                    // Scroll when messages become visible (after animation)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    }
                }
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Type your answer…", text: $message, axis: .vertical)
                    .focused($isInputFocused)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.2))
                    )
                
                Button {
                    sendMessage()
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
        .onAppear {
            let conv = chatStore.conversation(for: contextKey)
            if !conv.messages.isEmpty {
                // Restore conversation from store (reopening after dismiss)
                messages = conv.messages
                conversationId = conv.conversationId
                visibleMessageIds = conv.visibleMessageIds
            } else {
                // First open for this context — generate & animate greetings
                let greetings = generateInitialGreeting()
                messages = greetings

                // Animate each greeting bubble with staggered delay
                for (index, greeting) in greetings.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.4) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            _ = visibleMessageIds.insert(greeting.id)
                        }
                    }
                }
            }
        }
        .onDisappear {
            syncToStore()
        }
        .dismissKeyboardOnTap()
        .overlay(alignment: .topTrailing) {
            // Only show Skip button during onboarding flow
            if isOnboardingFlow {
                Button("Skip") {
                    AnalyticsService.shared.trackOnboarding("Onboarding Chat Dismissed", properties: [
                        "flow_type": coordinator.onboardingFlow.rawValue
                    ])

                    if let onDismiss {
                        onDismiss()
                    } else {
                        coordinator.dismissChatBot()
                    }

                    if coordinator.onboardingFlow == .individual {
                        coordinator.showCanvas(.summaryJustMe)
                    } else {
                        coordinator.showCanvas(.summaryAddFamily)
                    }
                }
                .font(NunitoFont.semiBold.size(14))
                .foregroundStyle(.grayScale120)
                .padding(.top, 16)
                .padding(.trailing, 16)
            }
        }
    }

    // MARK: - Initial Greeting

    private func generateInitialGreeting() -> [ChatMessage] {
        let context = buildContext()

        switch context {
        case _ as DTO.FeedbackContext:
            // Feedback context (product, ingredient, or image feedback)
            return [
                ChatMessage(
                    id: "greeting_1",
                    isUser: false,
                    text: "Hi! I see you have feedback about the analysis.",
                    timestamp: Date()
                ),
                ChatMessage(
                    id: "greeting_2",
                    isUser: false,
                    text: "What didn't seem right? I'm here to help improve the accuracy.",
                    timestamp: Date()
                )
            ]

        case _ as DTO.ProductScanContext:
            // Product scan context
            return [
                ChatMessage(
                    id: "greeting_1",
                    isUser: false,
                    text: "Hi! I see you're looking at a product.",
                    timestamp: Date()
                ),
                ChatMessage(
                    id: "greeting_2",
                    isUser: false,
                    text: "I can help explain ingredients, check dietary compatibility, or answer questions about this product.",
                    timestamp: Date()
                )
            ]

        case _ as DTO.FoodNotesContext:
            // Food notes context
            return [
                ChatMessage(
                    id: "greeting_1",
                    isUser: false,
                    text: "Hi! I'm here to help with your food preferences.",
                    timestamp: Date()
                ),
                ChatMessage(
                    id: "greeting_2",
                    isUser: false,
                    text: "Would you like to add or update dietary preferences, or learn how IngrediCheck analyzes products for you?",
                    timestamp: Date()
                )
            ]

        default:
            // Home context (default)
            return [
                ChatMessage(
                    id: "greeting_1",
                    isUser: false,
                    text: "Hi! I'm IngrediBot, your food assistant.",
                    timestamp: Date()
                ),
                ChatMessage(
                    id: "greeting_2",
                    isUser: false,
                    text: "How can I help you today? Ask me about:\n- Understanding ingredients\n- Setting up dietary preferences\n- How to scan products",
                    timestamp: Date()
                )
            ]
        }
    }

    // MARK: - Context Building

    private func buildContext() -> any Codable {
        // Build context based on provided parameters or current screen
        // Priority: feedbackId > scanId > food_notes > home

        // If feedbackId is provided, use feedback context
        if let feedbackId = feedbackId {
            return ChatContextBuilder.buildFeedbackContext(feedbackId: feedbackId)
        }

        // If scanId is provided (without feedbackId), use product_scan context
        if let scanId = scanId {
            return ChatContextBuilder.buildProductScanContext(scanId: scanId)
        }

        // Check if we're on food notes screen or in onboarding flow
        // During onboarding, user is setting up food preferences, so use food_notes context
        let isFoodNotes = coordinator.currentCanvasRoute == .summaryJustMe ||
                         coordinator.currentCanvasRoute == .summaryAddFamily ||
                         coordinator.currentCanvasRoute == .welcomeToYourFamily ||
                         isOnboardingFlow

        if isFoodNotes {
            return ChatContextBuilder.buildFoodNotesContext()
        }

        // Default to home context
        return ChatContextBuilder.buildHomeContext()
    }
    
    // MARK: - Send Message
    
    private func sendMessage() {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        let userMessage = trimmed
        isInputFocused = false  // Dismiss keyboard first
        message = ""            // Then clear message
        errorMessage = nil
        
        // Add user message immediately with animation
        let userMsg = ChatMessage(
            id: UUID().uuidString,
            isUser: true,
            text: userMessage,
            timestamp: Date()
        )
        messages.append(userMsg)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            _ = visibleMessageIds.insert(userMsg.id)
        }
        syncToStore()

        // Build context
        let context = buildContext()

        // Start streaming
        isStreaming = true
        currentTurnId = nil

        Task {
            do {
                let contextJson = try ChatContextBuilder.encodeContext(context)

                try await webService.streamChatMessage(
                    message: userMessage,
                    context: context,
                    conversationId: conversationId,
                    onThinking: { convId, turnId in
                        Task { @MainActor in
                            self.conversationId = convId
                            self.currentTurnId = turnId
                            // Typing indicator is already shown via isStreaming
                        }
                    },
                    onResponse: { convId, turnId, response in
                        Task { @MainActor in
                            self.conversationId = convId
                            self.currentTurnId = turnId
                            self.isStreaming = false

                            // Add bot response with animation
                            let botMsg = ChatMessage(
                                id: turnId,
                                isUser: false,
                                text: response,
                                timestamp: Date()
                            )
                            self.messages.append(botMsg)
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                _ = self.visibleMessageIds.insert(botMsg.id)
                            }
                            self.syncToStore()
                        }
                    },
                    onError: { error, convId, turnId in
                        Task { @MainActor in
                            self.isStreaming = false
                            self.conversationId = convId
                            self.currentTurnId = turnId
                            self.errorMessage = error.message

                            // Add error message to chat with animation
                            let errorMsg = ChatMessage(
                                id: UUID().uuidString,
                                isUser: false,
                                text: Microcopy.string(Microcopy.Key.Errors.genericToast),
                                timestamp: Date()
                            )
                            self.messages.append(errorMsg)
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                _ = self.visibleMessageIds.insert(errorMsg.id)
                            }
                            self.syncToStore()
                        }
                    }
                )
            } catch {
                Task { @MainActor in
                    self.isStreaming = false
                    self.errorMessage = error.localizedDescription

                    // Add error message to chat with animation
                    let errorMsg = ChatMessage(
                        id: UUID().uuidString,
                        isUser: false,
                        text: Microcopy.string(Microcopy.Key.Errors.genericToast),
                        timestamp: Date()
                    )
                    self.messages.append(errorMsg)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        _ = self.visibleMessageIds.insert(errorMsg.id)
                    }
                    self.syncToStore()
                }
            }
        }
    }
    
    // MARK: - Load Conversation History
    
    private func loadConversationHistoryIfNeeded() {
        guard let convId = conversationId, !isLoadingHistory else { return }

        isLoadingHistory = true

        Task {
            do {
                let conversation = try await webService.getConversation(conversationId: convId)

                await MainActor.run {
                    // Convert ConversationTurn to ChatMessage
                    var loadedMessages: [ChatMessage] = []

                    // Create ISO8601 formatter with fractional seconds support
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                    for turn in conversation.turns {
                        let timestamp = formatter.date(from: turn.created_at) ?? Date()

                        // Add user message
                        if !turn.user_message.isEmpty {
                            loadedMessages.append(ChatMessage(
                                id: "\(turn.turn_id)_user",
                                isUser: true,
                                text: turn.user_message,
                                timestamp: timestamp
                            ))
                        }

                        // Add assistant response if available
                        if let response = turn.assistant_response, !response.isEmpty {
                            loadedMessages.append(ChatMessage(
                                id: turn.turn_id,
                                isUser: false,
                                text: response,
                                timestamp: timestamp
                            ))
                        }
                    }

                    self.messages = loadedMessages
                    // Make all loaded messages visible immediately
                    self.visibleMessageIds = Set(loadedMessages.map { $0.id })
                    self.isLoadingHistory = false
                    self.syncToStore()
                }
            } catch {
                await MainActor.run {
                    self.isLoadingHistory = false
                    // Don't show error for 404 - just means no conversation yet
                    if let networkError = error as? NetworkError,
                       case .notFound = networkError {
                        // 404 is expected for new conversations - don't show error
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
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

    /// Parses the text as Markdown and returns an AttributedString
    private var markdownText: AttributedString {
        do {
            return try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        } catch {
            return AttributedString(text)
        }
    }

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
            
            Text(markdownText)
                .padding(12)
                .font(ManropeFont.regular.size(14))
                .foregroundStyle(textColor)
                .background(
                    RoundedCornerShape(radii: radii)
                        .fill(bubbleColor)
                )
                .tint(textColor.opacity(0.8))  // For Markdown links
            
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
            .environment(AppState())
            .environment(ChatStore())
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
