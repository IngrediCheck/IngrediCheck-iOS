//
//  LetsMeetYourIngrediFamView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 11/11/25.
//

import SwiftUI
import UIKit

struct LetsMeetYourIngrediFamView: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(FamilyStore.self) private var familyStore
    @Environment(WebService.self) private var webService
    
    private var shouldShowWelcomeFamily: Bool {
        switch coordinator.currentBottomSheetRoute {
        case .whosThisFor:
            return true
        default:
            return false
        }
    }
    
    private func initial(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }
        return String(first).uppercased()
    }
    
    // Helper view to display member avatar that handles both asset names and Supabase hashes
    struct MemberAvatarView: View {
        @Environment(WebService.self) private var webService
        let member: FamilyMember
        let initial: (String) -> String
        
        @State private var avatarImage: UIImage? = nil
        @State private var loadedHash: String? = nil
        
        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                // Show avatar with background color circle, or fallback with initial letter
                Circle()
                    .fill(Color(hex: member.color))
                    .frame(width: 48, height: 48)
                    .overlay {
                        if let img = avatarImage {
                            // Show memoji avatar over colored background
                            Image(uiImage: img)
                                .resizable()
                                .renderingMode(.original) // Preserve transparency
                                .scaledToFit() // Preserve aspect ratio
                                .frame(width: 46, height: 46) // Slightly smaller so thin color ring is visible
                                .clipShape(Circle())
                        } else {
                            // Fallback: initial letter
                            Text(initial(member.name))
                                .font(NunitoFont.semiBold.size(18))
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(lineWidth: 1)
                            .foregroundStyle(Color.white)
                    )
                
                // Edit button overlay
                Circle()
                    .fill(.grayScale40)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image("pen-line")
                            .frame(width: 7.43, height: 7.43)
                    )
                    .offset(x: -4, y: 4)
            }
            .task(id: member.imageFileHash) {
                await loadAvatarIfNeeded()
            }
        }
        
        @MainActor
        private func loadAvatarIfNeeded() async {
            guard let hash = member.imageFileHash, !hash.isEmpty else {
                avatarImage = nil
                loadedHash = nil
                return
            }
            
            // Skip if already loaded for this hash
            if loadedHash == hash, let existingImage = avatarImage {
                print("[LetsMeetYourIngrediFamView] loadAvatarIfNeeded: Before existingImage.size access - Thread.isMainThread=\(Thread.isMainThread)")
                let isValid = await MainActor.run {
                    let isMainThread = Thread.isMainThread
                    print("[LetsMeetYourIngrediFamView] loadAvatarIfNeeded: Inside MainActor.run (existingImage) - Thread.isMainThread=\(isMainThread)")
                    let width = existingImage.size.width
                    let height = existingImage.size.height
                    print("[LetsMeetYourIngrediFamView] loadAvatarIfNeeded: existingImage.size accessed - width=\(width), height=\(height)")
                    return width > 0 && height > 0
                }
                print("[LetsMeetYourIngrediFamView] loadAvatarIfNeeded: After MainActor.run (existingImage) - isValid=\(isValid)")
                if isValid {
                    return
                }
            }
            
            // Check if hash looks like an asset name (short, contains dashes) vs uploaded hash (long hex string)
            // Asset names are typically short like "image-bg1", hashes are 64-char hex strings
            if hash.count < 20 && hash.contains("-") {
                // Likely an asset name - try loading from assets
                if let assetImage = UIImage(named: hash) {
                    print("[LetsMeetYourIngrediFamView] loadAvatarIfNeeded: Before assetImage.size access - Thread.isMainThread=\(Thread.isMainThread)")
                    let isValid = await MainActor.run {
                        let isMainThread = Thread.isMainThread
                        print("[LetsMeetYourIngrediFamView] loadAvatarIfNeeded: Inside MainActor.run (assetImage) - Thread.isMainThread=\(isMainThread)")
                        let width = assetImage.size.width
                        let height = assetImage.size.height
                        print("[LetsMeetYourIngrediFamView] loadAvatarIfNeeded: assetImage.size accessed - width=\(width), height=\(height)")
                        return width > 0 && height > 0
                    }
                    print("[LetsMeetYourIngrediFamView] loadAvatarIfNeeded: After MainActor.run (assetImage) - isValid=\(isValid)")
                    if isValid {
                        avatarImage = assetImage
                        loadedHash = hash
                        return
                    }
                }
            }
            
            // Otherwise, fetch from Supabase
            print("[LetsMeetYourIngrediFamView] Loading avatar for \(member.name), imageFileHash=\(hash)")
            do {
                let uiImage = try await webService.fetchImage(
                    imageLocation: .imageFileHash(hash),
                    imageSize: .small
                )
                // CRITICAL: UIImage.size access must be on main thread
                print("[LetsMeetYourIngrediFamView] loadAvatarIfNeeded: Before uiImage.size access - Thread.isMainThread=\(Thread.isMainThread)")
                let isValid = await MainActor.run {
                    let isMainThread = Thread.isMainThread
                    print("[LetsMeetYourIngrediFamView] loadAvatarIfNeeded: Inside MainActor.run (uiImage) - Thread.isMainThread=\(isMainThread)")
                    let width = uiImage.size.width
                    let height = uiImage.size.height
                    print("[LetsMeetYourIngrediFamView] loadAvatarIfNeeded: uiImage.size accessed - width=\(width), height=\(height)")
                    return width > 0 && height > 0 && width.isFinite && height.isFinite
                }
                print("[LetsMeetYourIngrediFamView] loadAvatarIfNeeded: After MainActor.run (uiImage) - isValid=\(isValid)")
                guard isValid else {
                    print("[LetsMeetYourIngrediFamView] ⚠️ Loaded image has invalid size, skipping")
                    avatarImage = nil
                    loadedHash = nil
                    return
                }
                avatarImage = uiImage
                loadedHash = hash
                print("[LetsMeetYourIngrediFamView] ✅ Loaded avatar for \(member.name)")
            } catch {
                print("[LetsMeetYourIngrediFamView] ❌ Failed to load avatar for \(member.name): \(error.localizedDescription)")
                avatarImage = nil
                loadedHash = nil
            }
        }
    }
    
    var body: some View {
        if shouldShowWelcomeFamily {
            VStack {
               Text("Welcome to IngrediFam !")
                    .font(ManropeFont.bold.size(16))
                    .padding(.top ,32)
                    .padding(.bottom ,4)
                Text("Join your family space and personalize food choices together.")
                    .font(ManropeFont.regular.size(13))
                    .foregroundColor(Color(hex: "#BDBDBD"))
                    .lineLimit(2)
                    .frame(width : 247)
                    .multilineTextAlignment(.center )
                
                Image("onbordingfamilyimg2")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 369)
                    .frame(maxWidth: .infinity)
                    .offset(y : -50)
                
                Spacer()
            }
            .navigationBarBackButtonHidden(true)
        } else if let me = familyStore.pendingSelfMember {
            VStack(spacing: 12) {
                Text("Your Family Overview")
                    .font(NunitoFont.bold.size(18))
                    .foregroundStyle(.grayScale150)
                    .padding(.top, 32)

                HStack(spacing: 12) {
                    MemberAvatarView(member: me, initial: initial(from:))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(me.name)
                            .font(NunitoFont.semiBold.size(18))
                            .foregroundStyle(.grayScale150)
                        Text("(You)")
                            .font(NunitoFont.regular.size(12))
                            .foregroundStyle(.grayScale110)
                    }

                    Spacer()

//                    Text("Leave Family")
//                        .font(NunitoFont.semiBold.size(12))
//                        .foregroundStyle(.grayScale110)
//                        .padding(.vertical, 8)
//                        .padding(.horizontal, 18)
//                        .background(.grayScale40, in: .capsule)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(lineWidth: 0.75)
                                .foregroundStyle(Color(hex: "#EEEEEE"))
                            
                            
                            )
                )
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
                .onTapGesture {
                    coordinator.navigateInBottomSheet(.editMember(memberId: me.id, isSelf: true))
                }

                VStack(spacing: 12) {
                    ForEach(familyStore.pendingOtherMembers) { member in
                        HStack(spacing: 12) {
                            MemberAvatarView(member: member, initial: initial(from:))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                    .font(NunitoFont.semiBold.size(18))
                                    .foregroundStyle(.grayScale150)
                                if member.invitePending == true {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Color(hex: "F4A100"))
                                        Text("Pending")
                                            .font(ManropeFont.semiBold.size(12))
                                            .foregroundStyle(Color(hex: "F4A100"))
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 10)
                                    .background(
                                        Capsule()
                                            .fill(Color(hex: "FFF7E6"))
                                    )
                                }
                            }

                            Spacer()

                            Button {
                                coordinator.navigateInBottomSheet(.wouldYouLikeToInvite(memberId: member.id, name: member.name))
                            } label: {
                                HStack(spacing: 10) {
                                    Image( "share")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(hex: "91B640"))
                                    Text("Invite")
                                        .font(NunitoFont.semiBold.size(12))
                                        .foregroundStyle(Color(hex: "91B640"))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 18)
                                .background(
                                    Capsule().fill(Color.white)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(lineWidth: 1.5)
                                        .foregroundStyle(Color(hex: "91B640"))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white)
                                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(lineWidth: 0.75)
                                        .foregroundStyle(Color(hex: "#EEEEEE"))
                                )
                        )
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            coordinator.navigateInBottomSheet(.editMember(memberId: member.id, isSelf: false))
                        }
                    }
                }

                Spacer()
            }
            .navigationBarBackButtonHidden(true)
        } else {
            VStack {
               Text("Getting Started!")
                    .font(ManropeFont.bold.size(16))
                    .padding(.top ,32)
                    .padding(.bottom ,4)
                Text("Add profiles so IngredientCheck can personalize results for each person.")
                    .font(ManropeFont.regular.size(13))
                    .foregroundColor(Color(hex: "#BDBDBD"))
                    .lineLimit(2)
                    .frame(width : 247)
                    .multilineTextAlignment(.center )
                
                Image("addfamilyimg")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 369)
                    .frame(maxWidth: .infinity)
                    .offset(y : -50)
                
                Spacer()
            }
            .navigationBarBackButtonHidden(true)
        }
    }
}

/// Helper view for Onboarding avatars that supports both local assets and remote hashes.
fileprivate struct OnboardingSmartAvatarView: View {
    let imageName: String
    
    @Environment(WebService.self) private var webService
    @State private var remoteImage: UIImage? = nil
    
    var body: some View {
        ZStack {
            if let local = UIImage(named: imageName) {
                Image(uiImage: local)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
            } else if let remote = remoteImage {
                Image(uiImage: remote)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
            } else {
                // Loading / Placeholder
                Circle()
                    .fill(Color.grayScale20)
                    .frame(width: 42, height: 42)
                    .overlay(ProgressView().scaleEffect(0.5))
                    .task {
                        await loadRemote()
                    }
            }
        }
    }
    
    @MainActor
    private func loadRemote() async {
        do {
            let uiImage = try await webService.fetchImage(
                imageLocation: .imageFileHash(imageName),
                imageSize: .small
            )
            self.remoteImage = uiImage
        } catch {
            print("Failed to load onboarding avatar: \(error)")
        }
    }
}

#Preview {
    LetsMeetYourIngrediFamView()
}

