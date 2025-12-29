//
//  IngrediBotWithText.swift
//  IngrediCheckPreview
//
//  Created on 13/11/25.
//

import SwiftUI
import AVKit

struct IngrediBotWithText: View {
    let text: String
    var viewDidAppear: (() -> Void)? = nil
    var delay: TimeInterval = 2.0
    @State private var playerLooper: AVPlayerLooper?
    @State private var queuePlayer: AVQueuePlayer?
    
    private func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "IngrediBotLoading", withExtension: "mp4") else {
            return
        }
        let playerItem = AVPlayerItem(url: url)
        let newQueuePlayer = AVQueuePlayer(playerItem: playerItem)
        queuePlayer = newQueuePlayer
        
        // Set up looping
        playerLooper = AVPlayerLooper(player: newQueuePlayer, templateItem: playerItem)
        newQueuePlayer.play()
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Robot image
            if let queuePlayer = queuePlayer {
                VideoPlayer(player: queuePlayer)
                    .onAppear {
                        if playerLooper == nil {
                            setupPlayer()
                        } else {
                            queuePlayer.play()
                        }
                    }
                    .onDisappear {
                        playerLooper?.disableLooping()
                        playerLooper = nil
                        queuePlayer.pause()
                    }
                    .frame(width: 147, height: 147)
                    .clipped()
            } else {
                Image("ingrediBot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 147, height: 147)
                    .clipped()
                    .onAppear {
                        setupPlayer()
                    }
            }
            
            VStack(spacing: 24) {
                Text(text)
                    .font(NunitoFont.bold.size(20))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
        .onAppear() {
            if let viewDidAppear = viewDidAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    viewDidAppear()
                }
            }
        }
    }
}

#Preview {
    IngrediBotWithText(text: "Bringing your avatar to life... it's going to be awesome!")
}

