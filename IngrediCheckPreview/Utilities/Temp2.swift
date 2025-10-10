//
//  Temp2.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/10/25.
//

import SwiftUI

struct Temp2: View {
    
    @State private var scrollY: CGFloat = 0
    @State private var isExpanded: Bool = true
    @State private var prevValue: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
//                Rectangle()
//                    .fill(.white)
//                    .overlay(
//                        VStack {
//                            Text("\(scrollY)")
//                            
//                            Text(isExpanded ? "Big" : "small")
//                        }
//                    )
                
                ScrollView {
                    VStack {
                        ForEach(0..<50) { _ in
                            RecentScansRow()
                        }
                        
                    }
                    .padding()
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    scrollY = geo.frame(in: .named("scroll")).minY
                                }
                                .onChange(of: geo.frame(in: .named("scroll")).minY) { newValue in
                                    scrollY = newValue
                                    
                                    if scrollY < 0 && newValue < prevValue {
                                        isExpanded = false
                                    } else {
                                        isExpanded = true
                                    }
                                    
                                    prevValue = newValue
                                    
                                }
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
            }
            
            TabBar(isExpanded: $isExpanded)
        }
    }
}

#Preview {
    Temp2()
}
