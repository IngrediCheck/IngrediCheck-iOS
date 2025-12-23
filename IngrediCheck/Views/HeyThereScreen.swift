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
                    case .doYouHaveAnInviteCode, .enterInviteCode:
                        VStack {
                            Spacer()
                            Image("onbordingfamilyimg")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 269)
                                .frame(maxWidth: .infinity)
                            Spacer()
                        }
                    default:
                        EmptyView()
                    }
                }
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
            } else {
                VStack {
                    Image("Ingredicheck-logo")
                        .frame(width : 107.3 ,height: 36)
                        .padding(.top,44)
                        .padding(.bottom,33)

                    ZStack {
                        Image("Iphone-image")
                            .resizable()
                            .frame(width: 238 ,height: 460)
                    }
                    Spacer()
                }

                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color(
                                hex: "#FFFFFF"
                            ),
                            Color(
                                hex: "#F7F7F7"
                            )
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [

                            Color.white.opacity(0.1),
                            Color.white,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .offset(y: 75)
                )
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .task {
            // Trigger anonymous sign-in when .heyThere screen appears
            // This ensures all navigation after this point can sync to Supabase
            if authController.session == nil {
                print("[OnboardingMeta] Auto-triggering guest login on .heyThere screen")
                await authController.signIn()

                // Sync initial state to Supabase immediately after session is created
                // This ensures if user kills app right away, they can resume from this screen
                print("[OnboardingMeta] Syncing initial state after guest login")
                await authController.syncRemoteOnboardingMetadata(from: coordinator)
            }
        }
    }
}

#Preview {
    HeyThereScreen()
}
