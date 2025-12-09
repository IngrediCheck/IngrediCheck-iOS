//
//  AIMemojiTrigger.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 06/11/25.
//

import SwiftUI

struct AIMemojiTrigger: View {
    @State var AIimage: UIImage?
    @State var loading: Bool = false
    var body: some View {
        VStack {
            
            if let AIimage = AIimage {
                Image(uiImage: AIimage)
                    .resizable()
                    .frame(width: 100, height: 100)
            } else if loading {
                ProgressView()
            }
            
            Button {
                Task {
                    do {
                        loading = true
                        defer {
                            loading = false
                        }
                        print("started generating image")
                        let req = MemojiRequest(
                            familyType: "father",
                            gesture: "wave",
                            hair: "long",
                            skinTone: "light",
                            accessories: ["sunglass"],
                            background: "transparent",
                            size: "1024x1024",
                            model: "gpt-image-1",
                            subscriptionTier: "monthly_basic"
                        )
                        AIimage = try await generateMemojiImage(requestBody: req)
                        print("finished generating image")
                    } catch {
                        print("Error loading image: \(error)")
                    }
                }
            } label: {
                Text("Fetch Image")
            }
        }
    }
}

#Preview {
    AIMemojiTrigger()
}
