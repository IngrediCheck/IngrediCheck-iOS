//
//  IngrediFamCanvasView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 16/10/25.
//

import SwiftUI

struct GenerateAvatarTools: Identifiable {
    let id = UUID().uuidString
    var title: String
    var icon: String
    var tools: [ChipsModel]
}

enum AddFamilyMemberSheetOption: String, Identifiable {
    case meetYourIngrediFam
    case whatsYourName
    case addMoreMember
    case addMoreMembersMinimal
    case allSet
    case alreadyHaveAnAccount
    case doYouHaveAnInviteCode
    case generateAvatar
    case bringingYourAvatar
    case meetYourAvatar
    case letsScanSmarter
    case accessDenied
    case stayUpdated
    case preferenceAreReady
    case welcomeBack
    case whosThisFor
    case allSetToJoinYourFamily
    case enterYourInviteCode
    
    var id: String { self.rawValue }
}

struct IngrediFamCanvasView: View {
    
    @State var addFamilyMemberSheetOption: AddFamilyMemberSheetOption? = .allSet
    @State var isExpandedMinimal: Bool = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.grayScale10)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(lineWidth: 0.5)
                        .foregroundStyle(.grayScale60)
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .frame(height: 700)
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
            
            VStack(spacing: 20) {
                Button("welcomeBack") {
                    addFamilyMemberSheetOption = .welcomeBack
                }
                Button("whosThisFor") {
                    addFamilyMemberSheetOption = .whosThisFor
                }
                Button("allSetToJoinYourFamily") {
                    addFamilyMemberSheetOption = .allSetToJoinYourFamily
                }
                Button("enterYourInviteCode") {
                    addFamilyMemberSheetOption = .enterYourInviteCode
                }
                Button("addMoreMember") {
                    addFamilyMemberSheetOption = .addMoreMember
                }
                Button("addMoreMembersMinimal") {
                    addFamilyMemberSheetOption = .addMoreMembersMinimal
                }
                Button("allSet") {
                    addFamilyMemberSheetOption = .allSet
                }
                Button("alreadyHaveAnAccount") {
                    addFamilyMemberSheetOption = .alreadyHaveAnAccount
                }
                Button("doYouHaveAnInviteCode") {
                    addFamilyMemberSheetOption = .doYouHaveAnInviteCode
                }
                Button("meetYourIngrediFam") {
                    addFamilyMemberSheetOption = .meetYourIngrediFam
                }
                Button("whatsYourName") {
                    addFamilyMemberSheetOption = .whatsYourName
                }
                Button("generateAvatar") {
                    addFamilyMemberSheetOption = .generateAvatar
                }
                Button("meetYourAvatar") {
                    addFamilyMemberSheetOption = .meetYourAvatar
                }
                Button("letsScanSmarter") {
                    addFamilyMemberSheetOption = .letsScanSmarter
                }
                Button("accessDenied") {
                    addFamilyMemberSheetOption = .accessDenied
                }
                Button("stayUpdated") {
                    addFamilyMemberSheetOption = .stayUpdated
                }
                Button("preferenceAreReady") {
                    addFamilyMemberSheetOption = .preferenceAreReady
                }
                Button("bringYourAvatar") {
                    addFamilyMemberSheetOption = .bringingYourAvatar
                }
            }
        }
        CustomSheet(item: $addFamilyMemberSheetOption,
                    cornerRadius: 34) { sheet in
            switch sheet {
            case .addMoreMember:
                AddMoreMembers()
            case .addMoreMembersMinimal:
                AddMoreMembersMinimal()
            case .allSet:
                AllSet()
            case .alreadyHaveAnAccount:
                AlreadyHaveAnAccount()
                case .doYouHaveAnInviteCode:
                    DoYouHaveAnInviteCode()
            case .meetYourIngrediFam:
                MeetYourIngrediFam()
            case .whatsYourName:
                WhatsYourName()
            case .generateAvatar:
                GenerateAvatar(
                    isExpandedMinimal: $isExpandedMinimal,
                    randomPressed: { _ in },
                    generatePressed: { _ in }
                )
            case .bringingYourAvatar:
                IngrediBotWithText(text: "Bringing your avatar to life... it's going to be awesome!")
            case .meetYourAvatar:
                MeetYourAvatar()
            case .letsScanSmarter:
                LetsScanSmarter()
            case .accessDenied:
                AccessDenied()
            case .stayUpdated:
                StayUpdated()
            case .preferenceAreReady:
                PreferenceAreReady()
            case .welcomeBack:
                WelcomeBack()
            case .whosThisFor:
                WhosThisFor()
            case .allSetToJoinYourFamily:
                AllSetToJoinYourFamily()
            case .enterYourInviteCode:
                EnterYourInviteCode()
            }
        }
    }
}



#Preview {
    SetUpAvatarFor()
}
