//
//  WelcomeBack.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct WelcomeBack: View {
    @Environment(AuthController.self) var authController
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Text("Welcome back !")
                        .font(NunitoFont.bold.size(22))
                        .foregroundStyle(.grayScale150)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button {
                        // Go back one bottom sheet route
                        coordinator.navigateInBottomSheet(.alreadyHaveAnAccount)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 24, height: 24) // comfortable tap target
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Text("Log in to your existing IngrediCheck account.")
                    .font(ManropeFont.medium.size(12))                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)

            HStack(spacing: 16) {
                Button {
                    isSigningIn = true
                    authController.signInWithGoogle { result in
                        switch result {
                        case .success:
                            coordinator.showCanvas(.home)
                            isSigningIn = false
                        case .failure(let error):
                            print("Google Sign-In failed: \\(error.localizedDescription)")
                            isSigningIn = false
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image("google_logo")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text("Google")
                            .font(NunitoFont.semiBold.size(16))
                            .foregroundStyle(.grayScale150)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white, in: .capsule)
                    .overlay(
                        Capsule()
                            .stroke(Color.grayScale40, lineWidth: 1)
                    )
                }
                .disabled(isSigningIn)

                Button {
                    isSigningIn = true
                    authController.signInWithApple { result in
                        switch result {
                        case .success:
                            coordinator.showCanvas(.home)
                            isSigningIn = false
                        case .failure(let error):
                            print("Apple Sign-In failed: \\(error.localizedDescription)")
                            isSigningIn = false
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image("apple_logo")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text("Apple")
                            .font(NunitoFont.semiBold.size(16))
                            .foregroundStyle(.grayScale150)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white, in: .capsule)
                    .overlay(
                        Capsule()
                            .stroke(Color.grayScale40, lineWidth: 1)
                    )
                }
                .disabled(isSigningIn)
            }
           .padding(.bottom, 20)

//            HStack(spacing: 4) {
//                Text("New here?")
//                    .font(ManropeFont.regular.size(12))
//                    .foregroundStyle(.grayScale120)
//
//                Button {
//                    
//                } label: {
//                    Text("Get started instead")
//                        .font(ManropeFont.semiBold.size(12))
//                        .foregroundStyle(rotatedGradient(colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")], angle: 88))
//                }
//            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .center) {
            if isSigningIn {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(2)

                }
            }
        }
//        .overlay(
//            RoundedRectangle(cornerRadius: 4)
//                .fill(.neutral500)
//                .frame(width: 60, height: 4)
//                .padding(.top, 11)
//            , alignment: .top
//        )
        .navigationBarBackButtonHidden(true)
    }
}
