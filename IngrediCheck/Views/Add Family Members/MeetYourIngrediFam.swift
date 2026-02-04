//
//  MeetYourIngrediFam.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 28/10/25.
//

import SwiftUI

struct MeetYourIngrediFam: View {
    @State var addMemberPressed: () -> Void = { }
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(AppState.self) private var appState
    var body: some View {
        VStack(spacing: 20) {
            HStack{
                Image("IngrediFamGroup")
                    .resizable()
                    .frame(width: 295, height: 146)
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topLeading) {
                Button {
                    if coordinator.isCreatingFamilyFromSettings {
                        coordinator.isCreatingFamilyFromSettings = false
                        coordinator.showCanvas(.home)
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            appState.navigateToSettings = true
                        }
                    } else {
                        coordinator.navigateInBottomSheet(.whosThisFor)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            VStack(spacing: 16) {
                Microcopy.text(Microcopy.Key.Family.Setup.MeetYourIngrediFam.title)
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                
                Microcopy.text(Microcopy.Key.Family.Setup.MeetYourIngrediFam.subtitle)
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .frame(width : 338)
                    .multilineTextAlignment(.center)
                
                Button {
                    addMemberPressed()
                } label: {
                    GreenCapsule(title: Microcopy.string(Microcopy.Key.Common.continue))
                        .frame(width: 156)
                        .padding(.bottom ,30)
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .overlay(
//            RoundedRectangle(cornerRadius: 4)
//                .fill(.neutral500)
//                .frame(width: 60, height: 4)
//                .padding(.top, 11)
//            , alignment: .top
//        )
    }
}
