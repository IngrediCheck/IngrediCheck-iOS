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
    
    @State private var showLeaveConfirm = false
    
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
    
    // Helper view to display member avatar with edit button overlay
    struct MemberAvatarView: View {
        let member: FamilyMember
        let initial: (String) -> String
        
        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                // Use centralized MemberAvatar component
                MemberAvatar.medium(member: member)
                
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
        } else if let me = familyStore.family?.selfMember ?? familyStore.pendingSelfMember {
            VStack(spacing: 0) {
                Text("Your Family Overview")
                    .font(NunitoFont.bold.size(18))
                    .foregroundStyle(.grayScale150)
                    .padding(.top, 32)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 12) {
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

                            Button {
                                showLeaveConfirm = true
                            } label: {
                                Text("Leave Family")
                                    .font(NunitoFont.semiBold.size(12))
                                    .foregroundStyle(.grayScale110)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 18)
                                    .background(Color(hex: "#F2F2F2"), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .confirmationDialog("Leave Family", isPresented: $showLeaveConfirm) {
                                Button("Leave Family", role: .destructive) {
                                    print("[LetsMeetYourIngrediFamView] Leave Family confirmed")
                                    Task {
                                        print("[LetsMeetYourIngrediFamView] Calling familyStore.leave()")
                                        await familyStore.leave()
                                        let error = familyStore.errorMessage ?? "nil"
                                        print("[LetsMeetYourIngrediFamView] familyStore.leave() finished. errorMessage=\(error)")

                                        if familyStore.errorMessage == nil {
                                            print("[LetsMeetYourIngrediFamView] Leave success -> resetting local state and returning to start")
                                            familyStore.resetLocalState()
                                            coordinator.showCanvas(.heyThere)
                                        } else {
                                            print("[LetsMeetYourIngrediFamView] Leave failed -> staying on overview")
                                        }
                                    }
                                }
                            } message: {
                                Text("Are you sure you want to leave?")
                            }
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

                        let others = (familyStore.family?.otherMembers ?? []) + familyStore.pendingOtherMembers
                        // Remove duplicates if any (though pending should be cleared if family exists)
                        // Actually, if family exists, pendingOtherMembers should be empty after create/add.
                        // But if we are in AddMoreMembers flow, we might have added members to family immediately.
                        
                        ForEach(others) { member in
                            HStack(spacing: 12) {
                                MemberAvatarView(member: member, initial: initial(from:))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.name)
                                        .font(NunitoFont.semiBold.size(18))
                                        .foregroundStyle(.grayScale150)
                                    if member.invitePending == true || (!member.joined && member.id != me.id) {
                                        // Show pending for anyone not joined (except self which is assumed joined)
                                        // or if explicitly invitePending
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
                    .padding(.top, 10)
                    .padding(.bottom, UIScreen.main.bounds.height * 0.3)
                }
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

