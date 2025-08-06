//
//  temp.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 06/08/25.
//

import SwiftUI

struct temp: View {
    var body: some View {
        VStack {
            HStack {
                Circle()
                    .frame(width: 40, height: 40)
                
                Spacer()
                
                Menu {
                    Button {
                        print("New preference list")
                    } label: {
                        Label("New preference list", systemImage: "plus")
                    }

                    Button {
                        print("Mili's preference")
                    } label: {
                        Label("Mili's preference", systemImage: "checkmark")
                    }

                } label: {
                    HStack {
                        Text("Preference List")
                            .font(.headline)
                        Image(systemName: "chevron.down")
                    }
                }
                .foregroundStyle(.black)
                
                Spacer()
                
                HStack {
                    Image("arrow-export")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .padding(.trailing, 8)
                    
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            
            VStack {
                ColaboratorCard()
                    .padding(.top, 16)
                
                Spacer()
                
                VStack {
                    ZStack(alignment: .top) {
                        Image("task-Background")
                        Image("Tasks")
                    }
                    
                    Text("You don't have any dietary preferences entered yet")
                        .font(.footnote)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .frame(width: Constants.ScreenWidth / 2)
                }
                
                Spacer()
                
                Text("Try the following")
                    .font(.callout)
                    .foregroundStyle(.gray)
                
                Text("\"I follow a vegetarian diet, but i'm okay with eating fish.\"")
                    .padding(.horizontal, 8)
                    .padding(.vertical, 22)
                    .background(.gray.opacity(0.1))
                    .cornerRadius(6)
                
                Spacer()
                
                
            }
            .animation(.easeInOut)
            .padding(.horizontal, 16)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    temp()
}
