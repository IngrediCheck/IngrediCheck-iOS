//
//  LetsMeetYourIngrediFamView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 11/11/25.
//

import SwiftUI

struct LetsMeetYourIngrediFamView: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(FamilyStore.self) private var familyStore
    
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
            VStack(spacing: 20) {
                Text("Your Family Overview")
                    .font(NunitoFont.bold.size(18))
                    .foregroundStyle(.grayScale150)
                    .padding(.top, 32)

                HStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        if let imageName = me.imageFileHash {
                            ZStack{
                                Circle()
                                    .stroke(.grayScale40, lineWidth: 2)
                                .frame(width: 48, height: 48)
                                Image(imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 42, height: 42)
                                    .clipShape(Circle())
                            }
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: me.color))
                                    .frame(width: 42, height: 42 )
                                Text(initial(from: me.name))
                                    .font(NunitoFont.semiBold.size(18))
                                    .foregroundStyle(.white)
                            }
                        }
                        Circle()
                            .fill(.grayScale40)
                            .frame(width: 16, height: 16)
//                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            .overlay(
                                Image( "pen-line")
                                    .frame(width: 7.43, height:7.43)
                            )
                            .offset(x: -4, y: 4)
                    }

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
////                        .opacity(0.6)
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

                VStack(spacing: 12) {
                    ForEach(familyStore.pendingOtherMembers) { member in
                        HStack(spacing: 12) {
                            ZStack(alignment: .bottomTrailing) {
                                if let imageName = member.imageFileHash {
                                    ZStack{
                                        Circle()
                                            .stroke(.grayScale40, lineWidth: 2)
                                            .frame(width: 48, height: 48)
                                        Image(imageName)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 42, height: 42)
                                            .clipShape(Circle())
                                    }
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: member.color))
                                            .frame(width: 42, height: 42 )
                                        Text(initial(from: member.name))
                                            .font(NunitoFont.semiBold.size(18))
                                            .foregroundStyle(.white)
                                    }
                                }
                                Circle()
                                    .fill(.grayScale40)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Image("pen-line")
                                            .frame(width: 7.43, height:7.43)
                                    )
                                    .offset(x: -4, y: 4)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                    .font(NunitoFont.semiBold.size(18))
                                    .foregroundStyle(.grayScale150)
                            }

                            Spacer()
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
                    }
                }
                .padding(.top, 12)

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
//        ZStack {
//            VStack {
//                RoundedRectangle(cornerRadius: 24)
//                    .foregroundStyle(.white)
//                    .frame(width: UIScreen.main.bounds.width * 0.9)
//                    .shadow(color: .gray.opacity(0.5), radius: 9, x: 0, y: 0)
//            }
//            
//            VStack {
//                Spacer()
//                Text("Let's meet your IngrediFam")
//                
//                Spacer()
//                Spacer()
//                Spacer()
//            }
//        }
    }
}

#Preview {
    LetsMeetYourIngrediFamView()
}
