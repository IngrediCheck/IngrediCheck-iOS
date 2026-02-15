//
//  HeyThereScreen.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 07/11/25.
//

import SwiftUI

struct HeyThereScreen: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(AuthController.self) private var authController

    private var showOnboardingFamilyImage: Bool {
        switch coordinator.currentBottomSheetRoute {
        case .doYouHaveAnInviteCode, .enterInviteCode, .whosThisFor:
            return true
        default:
            return false
        }
    }
    
    var body: some View {
        Group {
            if showOnboardingFamilyImage {
                Group {
                    switch coordinator.currentBottomSheetRoute {
                    case .whosThisFor:
                        VStack {
                            Text("Welcome to IngrediFam!")
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
                    case .doYouHaveAnInviteCode, .enterInviteCode:
                        VStack {
                            Text("Welcome to IngrediFam!")
                                .font(ManropeFont.bold.size(16))
                                .padding(.top ,32)
                                .padding(.bottom ,4)
                            Text("Join your family space and personalize food choices together.")
                                .font(ManropeFont.regular.size(13))
                                .foregroundColor(Color(hex: "#BDBDBD"))
                                .lineLimit(2)
                                .frame(width : 247)
                                .multilineTextAlignment(.center )

                           
                            Image("onbordingfamilyimg")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 369)
                                .frame(maxWidth: .infinity)
                                .offset(y : -50)
                            Spacer()
                        }
                    default:
                        EmptyView()
                    }
                }
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
            } else {
                OnboardingPhoneCanvas(phoneImageName: "Iphone-image")
            }
        }
        .onAppear {
            if OnboardingPersistence.shared.localStage != .completed {
                AnalyticsService.shared.trackOnboarding("Onboarding Started")
            }
        }
        .task(id: coordinator.currentBottomSheetRoute) {
            if coordinator.currentBottomSheetRoute == .whosThisFor {
                if authController.session == nil {
                    print("[OnboardingMeta] Auto-triggering guest login on .whosThisFor screen")
                    await authController.signIn()

                    // signIn() creates an internal unstructured Task that survives
                    // cancellation, so the sign-in completes regardless. But post-work
                    // (sync, video download) should only run if we're still on this route.
                    if !Task.isCancelled {
                        print("[OnboardingMeta] Syncing initial state after guest login")
                        await OnboardingPersistence.shared.sync(from: coordinator)
                        Task { await TutorialVideoManager.shared.downloadIfNeeded() }
                    }
                }
            }
        }
    }
}

#Preview {
    HeyThereScreen()
        .environment(AppNavigationCoordinator(initialRoute: .heyThere))
        .environment(AuthController())
}
