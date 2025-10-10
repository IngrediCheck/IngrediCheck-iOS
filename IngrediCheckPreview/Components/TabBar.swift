//
//  TabBar.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 09/10/25.
//

import SwiftUI

struct TabBar: View {
    
    @State var scale: CGFloat = 1.0
    @State var offsetY: CGFloat = 0
    @State var isExpanded: Bool = true
    
    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                HStack(alignment: .center) {
                    Image("tabBar-heart")
                        .renderingMode(.template)
                        .resizable()
                        .foregroundColor(Color(hex: "676A64"))
                        .frame(width: 26, height: 26)
                    
                    Spacer()
                    
                    Image("tabBar-ingredibot")
                        .renderingMode(.template)
                        .resizable()
                        .foregroundColor(Color(hex: "676A64"))
                        .frame(width: 26, height: 26)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12.5)
                .frame(width: 196)
                .background(
                    Capsule()
                        .fill(.white)
                        .shadow(color: Color(hex: "E9E9E9"), radius: 13.6, x: 0, y: 12)
                )
                .overlay(
                    Capsule()
                        .stroke(lineWidth: 0.25)
                        .foregroundStyle(.grayScale50)
                )
                .scaleEffect(scale)
                .offset(y: offsetY)
                
                ZStack {
                    Circle()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "86AD17"), Color(hex: "688C00")], startPoint: .topTrailing, endPoint: .bottomLeading)
                                .shadow(
                                    .inner(color: Color(hex: "DAFF67").opacity(0.5), radius: 4, x: 0, y: 4)
                                )
                                .shadow(
                                    .drop(color: Color(hex: "DEDEDE"), radius: 5, x: 0, y: 4)
                                )
                        )
                    
                    
                    Image("tabBar-scanner")
                        .resizable()
                        .frame(width: 32, height: 32)
                    
                }
                .padding(.bottom, 18)
            }
            
            VStack {
                
                Spacer()
                
                Button {
                    withAnimation(.smooth) {
                        
                        if isExpanded {
                            withAnimation(.smooth) {
                                offsetY = 25
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.smooth) {
                                    scale = 0.1
                                }
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.smooth) {
                                    offsetY = 0
                                }
                            }
                            
                        } else {
                            withAnimation(.smooth) {
                                offsetY = 25
                            }
                            
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.smooth) {
                                    scale = 1
                                }
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.smooth) {
                                    offsetY = 0
                                }
                            }
                        }
                        
                        isExpanded.toggle()
                    }
                } label: {
                    Text("Toggle")
                }
                
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        TabBar()
    }
}
