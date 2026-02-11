//
//  MeetYourAvatar.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI
import DotLottie

struct MeetYourAvatar: View {
    let image: UIImage?
    let backgroundColorHex: String?
    let regeneratePressed: () -> Void
    let assignedPressed: () async -> Void
    @State private var showConfetti = false
    @State private var isAssigning = false
    @Environment(MemojiStore.self) private var memojiStore
    
    // Helper function to get the display name with possessive form
    private var displayText: String {
        if let typedName = memojiStore.displayName, !typedName.isEmpty {
            // Use the typed name with possessive form
            return "Meet \(typedName)'s avatar,\nlooking good!"
        } else {
            // Fallback to family member type if no typed name
            let memberType = memojiStore.selectedFamilyMemberName
            let possessiveName = getPossessiveName(for: memberType)
            return "Meet your \(possessiveName) avatar,\nlooking good!"
        }
    }
    
    // Helper function to convert family member type to possessive form
    private func getPossessiveName(for memberType: String) -> String {
        switch memberType.lowercased() {
        case "father":
            return "dad's"
        case "mother":
            return "mom's"
        case "grandfather":
            return "grandfather's"
        case "grandmother":
            return "grandmother's"
        case "baby-boy":
            return "baby boy's"
        case "baby-girl":
            return "baby girl's"
        case "young-boy":
            return "young boy's"
        case "young-girl":
            return "young girl's"
        default:
            return "\(memberType)'s"
        }
    }
    
    init(image: UIImage? = nil, backgroundColorHex: String? = nil, regeneratePressed: @escaping () -> Void = {}, assignedPressed: @escaping () async -> Void = {}) {
        self.image = image
        self.backgroundColorHex = backgroundColorHex
        self.regeneratePressed = regeneratePressed
        self.assignedPressed = assignedPressed
    }
    
    var body: some View {
        let circleColor = Color(hex: backgroundColorHex ?? "F2F2F2")
        
        VStack(spacing: 20) {
            // Avatar with background circle
            ZStack {
                // Background circle (behind the image)
                Circle()
                    .fill(circleColor)
                    .frame(width: 137, height: 137)
                
                // Memoji image on top (transparent PNG should show circle through)
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .renderingMode(.original) // Preserve transparency
                        .scaledToFit() // Preserve aspect ratio
                        .frame(width: 137, height: 137)
                        .clipShape(Circle())
                }
            }
            
            VStack(spacing: 40) {
                Text(displayText)
                    .font(NunitoFont.bold.size(18))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 12) {
                    SecondaryButton(
                        title: "Regenerate",
                        icon: "stars-generate",
                        iconWidth: 20,
                        iconHeight: 20,
                        action: regeneratePressed
                    )
                    
                    Button {
                        Task {
                            isAssigning = true
                            await assignedPressed()
                            isAssigning = false
                        }
                    } label: {
                        GreenCapsule(title: "Assign", isLoading: isAssigning)
                    }
                    .disabled(isAssigning)
                }
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
        .overlay {
            if showConfetti {
                DotLottieAnimation(
                    fileName: "Confetti",
                    config: AnimationConfig(autoplay: true, loop: true)
                )
                .view()
                .ignoresSafeArea()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showConfetti = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.4) {
                showConfetti = false
            }
        }
    }
}
