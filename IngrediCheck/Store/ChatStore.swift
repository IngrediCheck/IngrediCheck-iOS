//
//  ChatStore.swift
//  IngrediCheck
//

import SwiftUI
import Observation

// Chat message model
struct ChatMessage: Identifiable {
    let id: String
    let isUser: Bool
    let text: String
    let timestamp: Date
}

@Observable
@MainActor
final class ChatStore {
    /// Keyed by context string (e.g. "home", "product_scan:abc-123")
    private var conversations: [String: Conversation] = [:]

    struct Conversation {
        var messages: [ChatMessage] = []
        var conversationId: String? = nil
        var visibleMessageIds: Set<String> = []
    }

    func conversation(for contextKey: String) -> Conversation {
        conversations[contextKey] ?? Conversation()
    }

    func update(for contextKey: String, _ mutate: (inout Conversation) -> Void) {
        var conv = conversations[contextKey] ?? Conversation()
        mutate(&conv)
        conversations[contextKey] = conv
    }
}
