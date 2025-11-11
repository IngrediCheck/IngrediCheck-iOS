//
//  LetsMeetYourIngrediFamView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 11/11/25.
//

import SwiftUI

enum LetsMeetYourIngrediFamSheetOption: String, Identifiable {
    case letsMeetYourIngrediFam
    case whatsYourName
    case addMoreMembers
    case addMoreMembersMinimal
    case generateAvatar
    case bringingYourAvatar
    case meetYourAvatar
    
    var id: String {
        return self.rawValue
    }
}

struct LetsMeetYourIngrediFamView: View {
    @State var letsMeetYourIngrediFamSheetOption: LetsMeetYourIngrediFamSheetOption? = nil
    @State var isExpandedMinimal: Bool = false
    @State var goToDietartPreferenceScreen: Bool = false
    var body: some View {
        ZStack {
            
            CustomSheet(item: $letsMeetYourIngrediFamSheetOption,
                        cornerRadius: 34,
                        heightsForItem: { sheet in
                            switch sheet {
                            case .letsMeetYourIngrediFam: return (min: 396, max: 397)
                            case .whatsYourName: return (min: 375, max: 376)
                            case .addMoreMembers: return (min: 375, max: 376)
                            case .addMoreMembersMinimal: return (min: 270, max: 271)
                            case .generateAvatar: return (min: 379, max: 642)
                            case .bringingYourAvatar: return (min: 281, max: 282)
                            case .meetYourAvatar: return (min: 390, max: 391)
                            }
                        }) { sheet in
                switch sheet {
                case .letsMeetYourIngrediFam: MeetYourIngrediFam {
                    letsMeetYourIngrediFamSheetOption = .whatsYourName
                }
                case .whatsYourName: WhatsYourName {
                    letsMeetYourIngrediFamSheetOption = .generateAvatar
                } addMemberPressed: {
                    letsMeetYourIngrediFamSheetOption = .addMoreMembers
                }

                case .addMoreMembers: AddMoreMembers {
                    letsMeetYourIngrediFamSheetOption = .generateAvatar
                } addMemberPressed: {
                    letsMeetYourIngrediFamSheetOption = .addMoreMembersMinimal
                }

                case .addMoreMembersMinimal: AddMoreMembersMinimal {
                    letsMeetYourIngrediFamSheetOption = nil
                    goToDietartPreferenceScreen = true
                } addMorePressed: {
                    letsMeetYourIngrediFamSheetOption = .addMoreMembers
                }

                case .generateAvatar: GenerateAvatar(isExpandedMinimal: $isExpandedMinimal) {
                    letsMeetYourIngrediFamSheetOption = .bringingYourAvatar
                } generatePressed: {
                    letsMeetYourIngrediFamSheetOption = .bringingYourAvatar
                }

                case .bringingYourAvatar: BringingYourAvatar {
                    letsMeetYourIngrediFamSheetOption = .meetYourAvatar
                }
                case .meetYourAvatar: MeetYourAvatar {
                    letsMeetYourIngrediFamSheetOption = .bringingYourAvatar
                } assignedPressed: {
                    letsMeetYourIngrediFamSheetOption = .addMoreMembersMinimal
                }

                }
            }
            
            VStack {
                RoundedRectangle(cornerRadius: 24)
                    .foregroundStyle(.white)
                    .frame(width: UIScreen.main.bounds.width * 0.9)
                    .shadow(color: .gray.opacity(0.5), radius: 9, x: 0, y: 0)
                
                NavigationLink(destination: DietaryPreferencesAndRestrictions(isFamilyFlow: true), isActive: $goToDietartPreferenceScreen) {
                    EmptyView()
                }
            }
            
            VStack {
                Spacer()
                Text("Let's meet your IngrediFam")
                
                Spacer()
                Spacer()
                Spacer()
            }
            .onAppear() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    letsMeetYourIngrediFamSheetOption = .letsMeetYourIngrediFam
                }
            }
        }
    }
}

#Preview {
    LetsMeetYourIngrediFamView()
}
