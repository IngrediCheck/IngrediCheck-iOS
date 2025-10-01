//
//  CollapseFamilyList.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import SwiftUI

struct CollapseFamilyList: View {
    
    @State var collapsed: Bool = false
    @State var familyNames: [String] = [
        "father",
        "mother",
        "elder",
        "younger",
        "brother",
        "sister",
        "neighbour",
        "nepew",
        "grandmother",
        "grandfather"
    ]
    @State var selectedItem: String = ""
    
    var body: some View {
        ScrollView {
            ZStack {
                ZStack {
                    ForEach(Array(familyNames.reversed().enumerated()), id: \.element) { idx, ele in
                        let correctIdx = (idx - familyNames.count + 1) * -1
                        
                        if correctIdx < 3 {
                            nameRow(name: "\(ele): \(idx)")
                                .offset(y: collapsed ? CGFloat(correctIdx) * 60 : CGFloat(correctIdx * 8))
                                .opacity(collapsed ? 1 : 1.0 - Double(correctIdx + 1) * 0.2)
                                .padding(.horizontal, collapsed ? 0 : CGFloat(correctIdx + 1) * 10)
                                .onTapGesture {
                                    if collapsed {
                                        selectedItemPressed(item: ele)
                                    }
                                    withAnimation(.spring(dampingFraction: 0.7)) {
                                        collapsed.toggle()
                                    }
                                }
                        } else {
                            nameRow(name: "\(ele): \(idx)")
                                .offset(y: collapsed ? CGFloat(correctIdx) * 60 : 0)
                                .opacity(collapsed ? 1 : 0)
                                .padding(.horizontal, collapsed ? 0 : CGFloat(correctIdx) * 10)
                                .onTapGesture {
                                    if collapsed {
                                        selectedItemPressed(item: ele)
                                    }
                                    withAnimation(.spring(dampingFraction: 0.7)) {
                                        collapsed.toggle()
                                    }
                                }
                        }
                    }
                }
                .offset(y: collapsed ? 60 : 10)
                
                nameRow(name: "selected: \(selectedItem)")
                    .onTapGesture {
                        withAnimation(.spring(dampingFraction: 0.7)) {
                            collapsed.toggle()
                        }
                    }
            }
            .padding(.horizontal)
        }
        .onAppear() {
            selectedItemPressed(item: familyNames.first!)
        }
    }
    
    func selectedItemPressed(item: String) {
        let temp = selectedItem
        selectedItem = item
        familyNames.removeAll { $0 == item } // removes matching value
        if !temp.isEmpty {
            familyNames.append(temp)
        }
    }
    
    @ViewBuilder
    func nameRow(name: String) -> some View {
        HStack {
            Text(name.capitalized)
            
            Spacer()
            
            Circle()
                .frame(width: 20, height: 20)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.red)
        )
    }
}

#Preview {
    CollapseFamilyList()
//        .padding(.horizontal, 10)
}


// MARK: Below numbers are for refrence and testing

//nameRow(name: "younger")
//    .offset(y: collapsed ? 24 :  180)
//    .opacity(collapsed ? 0.4 : 1)
//    .padding(.horizontal, collapsed ? 30 : 0)
//
//nameRow(name: "elder")
//    .offset(y: collapsed ? 16 :  120)
//    .opacity(collapsed ? 0.6 : 1)
//    .padding(.horizontal, collapsed ? 20 : 0)
//    
//
//nameRow(name: "mother")
//    .offset(y: collapsed ? 8 : 60)
//    .opacity(collapsed ? 0.8 : 1)
//    .padding(.horizontal, collapsed ? 10 : 0)
//
//nameRow(name: "father")
