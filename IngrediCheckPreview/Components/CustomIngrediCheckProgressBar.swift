//
//  CustomIngrediCheckProgressBar.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 03/10/25.
//

import SwiftUI

struct CustomIngrediCheckProgressBar: View {
    
    @State var progress: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .leading) {
            
            Capsule()
                .fill(Color(hex: "#EEEEEE"))
                .frame(height: 4)
                .padding(.horizontal, 24)
            
            ZStack(alignment: .trailing) {
                Capsule()
                    .fill(.secondary600)
                    .frame(width: (UIScreen.main.bounds.width - 48) * progress / 100, height: 4)
                    .padding(.horizontal, 24)
                
                VStack(spacing: 0) {
                    Text("\(Int(progress))%")
                        .font(NunitoFont.bold.size(12))
                        .foregroundStyle(.primary700)
                    
                    ZStack(alignment: .center) {
                        Image("orange")
                            .resizable()
                            .frame(width: 17.39, height: 17.83)
                            .offset(y: -3)
                            .scaleEffect(progress > 0 ? 1 :1.2)
                        
                        Image("magnify")
                            .resizable()
                            .frame(width: 24, height: 27.16)
                            .offset(x: -2)
                            .opacity(progress > 0 ? 1 : 0)
                            .animation(.smooth, value: progress)
                    }
                }
                .padding(.trailing, 12)
                .offset(y: -8)
            }
            
            VStack {
                
                
                
                Button {
                    withAnimation(.smooth) {
                        progress += 10
                    }
                } label: {
                    Text("Press")
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    CustomIngrediCheckProgressBar()
}
