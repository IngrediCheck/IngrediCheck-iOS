//
//  ChatbotTextField.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 30/10/25.
//

import SwiftUI

struct ChatbotTextField: View {
    @State private var text: String = ""
    var onSend: (String) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Microcopy.text(Microcopy.Key.Chat.inputPlaceholder)
                        .font(NunitoFont.italic.size(16))
                        .foregroundStyle(.grayScale100)
                }

                // Empty label, custom placeholder handled above
                TextField("", text: $text, axis: .vertical)
                    .font(NunitoFont.regular.size(16))
                    .foregroundStyle(.grayScale150)
                    .submitLabel(.send)
                    .onSubmit {
                        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        onSend(text)
                        text.removeAll()
                    }
            }

            Button {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                onSend(trimmed)
                text.removeAll()
            } label: {
                Image("chatbot-send")
                    .resizable()
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.grayScale10)
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(lineWidth: 0.5)
                        .foregroundStyle(.grayScale60)
                )
        )
        .dismissKeyboardOnTap()
    }
}

#Preview {
    ChatbotTextField()
}
