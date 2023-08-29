//
//  Backend.swift
//  ShouldIEat
//
//  Created by sanket patel on 8/29/23.
//

import Foundation
import OpenAIKit

class Backend {

    private var openAIClient: OpenAIKit.Client

    init() {
        let apiKey = getConfigValue(for: "OPENAI_API_KEY")
        let organization = getConfigValue(for: "OPENAI_ORG_ID")
        let urlSession = URLSession(configuration: .default)
        let configuration = Configuration(apiKey: apiKey, organization: organization)
        self.openAIClient = OpenAIKit.Client(session: urlSession, configuration: configuration)
    }
    
    func generateRecommendation(ingredients: String, userPreference: String) async throws -> String? {
        
        let messages: [Chat.Message] = [
            Chat.Message.system(content:
                "You are an expert nutritionist. Your task is to read a list of ingredients of a packaged " +
                "food item, consider the human's dietary preferences, and then provide a recommendation " +
                "on whether or not the human should eat the packaged food item. If recommendation is No, " +
                "list all ingredients that are against the human's dietary preferences."
                ),
            Chat.Message.user(content:
                "Ingredients:\n" +
                "```\n" +
                "\(ingredients)\n" +
                "```\n" +
                "Human's dietary preferences:\n" +
                "```\n" +
                "\(userPreference)\n" +
                "```\n" +
                "Should I eat?"
                )
        ]
        
        print("OpenAI User Preference:\n\(userPreference)")
        
        let chat = try await openAIClient.chats.create(
            model: Model.GPT4.gpt4,
            messages: messages,
            temperature: 0.1)
        
        let response = chat.choices.first?.message.content
        
        print("OpenAI Response:\n\(response ?? "Empty")")
        
        return response
    }
    
    func extractIngredients(ocrText: String) async throws -> String? {
        
        let messages: [Chat.Message] = [
            Chat.Message.system(content:
                "You are an expert text extractor. Below is OCR text from the picture of " +
                "a packaged food item. Your task is to extract the list of ingredients from " +
                "this blob of text. The list of ingredients generally starts with 'INGREDIENTS'."
                ),
            Chat.Message.user(content:
                "OCR Text of packaged food item picture:\n" +
                "```\n" +
                "\(ocrText)\n" +
                "```\n"
                )
        ]
        
        print("OpenAI OCR Text:\n\(ocrText)")

        let chat = try await openAIClient.chats.create(
            model: Model.GPT4.gpt4,
            messages: messages,
            temperature: 0.1)
        
        let response = chat.choices.first?.message.content
        
        print("OpenAI Ingredients:\n\(response ?? "Empty")")
        
        return response
    }
}

// Store API keys in secrets.plist
// Example: secrets.plist.example
func getConfigValue(for key: String) -> String {
    if let path = Bundle.main.path(forResource: "secrets", ofType: "plist"),
       let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
        return dict[key] as? String ?? ""
    }
    return ""
}
