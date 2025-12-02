//
//  FineTuneYourExperience.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar on 02/12/25.
//

import SwiftUI

struct FineTuneYourExperience: View {
    var allSetPressed: () -> Void
    var addPreferencesPressed: () -> Void
    
    init(
        allSetPressed: @escaping () -> Void = {},
        addPreferencesPressed: @escaping () -> Void = {}
    ) {
        self.allSetPressed = allSetPressed
        self.addPreferencesPressed = addPreferencesPressed
    }
    
    var body: some View {
        VStack {
            VStack(spacing: 12) {
                Text("Want to fine-tune your experience?")
                    .font(NunitoFont.bold.size(20))
                    .foregroundStyle(.grayScale150)
                
                Text("Add extra preferences to tailor your experience.\n Jump in or skip!")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)
            
            HStack(spacing: 16) {
                Button {
                    allSetPressed()
                } label: {
                    Text("All Set!")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .frame(width: 160, height: 52)
                        .background(
                            .grayScale40, in: RoundedRectangle(cornerRadius: 28)
                        )
                }

                
                Button {
                    addPreferencesPressed()
                } label: {
                    GreenCapsule(title: "Add Preferences", width: 160, height: 52)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}

#Preview {
    FineTuneYourExperience()
}
