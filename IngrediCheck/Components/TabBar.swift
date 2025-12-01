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
    @Binding var isExpanded: Bool
    @State private var isCameraPresented = false
    
    var body: some View {
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
            
            Button {
                isCameraPresented = true
            } label: {
                ZStack {
                    Circle()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color(hex: "91C206"), location: 0.2),
                                    .init(color: Color(hex: "6B8E06"), location: 0.7)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                                .shadow(
                                    .inner(color: Color(hex: "99C712"), radius: 2.5, x: 4, y: -2.5)
                                )
                                .shadow(
                                    .drop(color: Color(hex: "606060").opacity(0.35), radius: 3.3, x: 0, y: 4)
                                )
                        )
                        .rotationEffect(.degrees(18))
                    
                    Image("tabBar-scanner")
                        .resizable()
                        .frame(width: 32, height: 32)
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 18)
        }
        .onChange(of: isExpanded) { oldValue, newValue in
            something()
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraScreen()
        }
    }
    
    
    func something() {
        withAnimation(.smooth) {
            
            if isExpanded {
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
                
            } else {
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
            }
            
        }

    }
    
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        TabBar(isExpanded: .constant(true))
    }
}
