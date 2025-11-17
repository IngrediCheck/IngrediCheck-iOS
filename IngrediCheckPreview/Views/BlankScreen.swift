//
//  BlankScreen.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

enum BlankScreenSheetOptions: String, CaseIterable, Identifiable {
    case doYouHaveAnInviteCode
    case enterInviteCode
    
    var id: String { self.rawValue }
}

struct BlankScreen: View {
    
    @State var blankSheetOption: BlankScreenSheetOptions? = nil
    @State var letsGetStartedView: Bool = false
    @State var welcomeToYourFamilyView: Bool = false
    
    var body: some View {
        ZStack {
            
            CustomSheet(item: $blankSheetOption, cornerRadius: 34, content: { sheet in
                switch sheet {
                    
                case .doYouHaveAnInviteCode: DoYouHaveAnInviteCode {
                    blankSheetOption = .enterInviteCode
                } noPressed: {
                    blankSheetOption = nil
                    letsGetStartedView = true
                }

                case .enterInviteCode: EnterYourInviteCode(yesPressed:  {
                    blankSheetOption = nil
                    welcomeToYourFamilyView = true
                })
                }
            })
            
            VStack {
                NavigationLink(destination: LetsGetStartedView(), isActive: $letsGetStartedView) {
                    EmptyView()
                }
                
                NavigationLink(destination: WelcomeToYourFamilyView(), isActive: $welcomeToYourFamilyView) {
                    EmptyView()
                }
            }
            .onAppear() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    blankSheetOption = .doYouHaveAnInviteCode
                }
                
            }
        }
    }
}

#Preview {
    BlankScreen()
}
