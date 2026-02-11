//
//  ConfettiView.swift
//  IngrediCheckPreview
//
//  Created on 12/12/25.
//

import SwiftUI

struct ConfettiView: View {
    @State private var confettiParticles: [ConfettiParticle] = []
    
    let colors: [Color] = [
        Color(hex: "9DCF10"), // Green
        Color(hex: "FFD700"), // Gold
        Color(hex: "FF6B6B"), // Red
        Color(hex: "4ECDC4"), // Teal
        Color(hex: "95E1D3"), // Mint
        Color(hex: "F38181"), // Pink
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiParticles) { particle in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size * 1.5)
                        .rotationEffect(.degrees(particle.rotation))
                        .position(
                            x: particle.x,
                            y: particle.y
                        )
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                startConfetti(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func startConfetti(in size: CGSize) {
        confettiParticles = []
        let particleCount = 60
        
        for i in 0..<particleCount {
            let startX = size.width / 2 + CGFloat.random(in: -50...50)
            let delay = Double(i) * 0.015
            let fallDuration = Double.random(in: 1.5...2.5)
            let horizontalSpread = CGFloat.random(in: -150...150)
            
            let particle = ConfettiParticle(
                id: UUID(),
                x: startX,
                y: -20,
                size: CGFloat.random(in: 8...14),
                color: colors.randomElement() ?? colors[0],
                opacity: 1.0,
                delay: delay,
                rotation: 0,
                horizontalSpread: horizontalSpread,
                fallDuration: fallDuration
            )
            confettiParticles.append(particle)
        }
        
        // Animate particles falling with rotation
        for i in confettiParticles.indices {
            let particle = confettiParticles[i]
            withAnimation(.linear(duration: particle.fallDuration).delay(particle.delay)) {
                confettiParticles[i].y = size.height + 100
                confettiParticles[i].x += particle.horizontalSpread
                confettiParticles[i].rotation = Double.random(in: 0...360)
            }
        }
        
        // Fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                for i in confettiParticles.indices {
                    confettiParticles[i].opacity = 0
                }
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let color: Color
    var opacity: Double
    let delay: Double
    var rotation: Double
    let horizontalSpread: CGFloat
    let fallDuration: Double
}

#Preview {
    ConfettiView()
        .frame(width: 400, height: 800)
}
