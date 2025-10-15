//
//  CollapseFamilyList.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import SwiftUI

struct CollapseFamilyList: View {
    
    @State var collapsed: Bool = false
    @State var familyNames: [UserModel] = [
        UserModel(familyMemberName: "father", familyMemberImage: "Father"),
        UserModel(familyMemberName: "mother", familyMemberImage: "Mother"),
        UserModel(familyMemberName: "son", familyMemberImage: "Son"),
        UserModel(familyMemberName: "daughter", familyMemberImage: "Daughter"),
        UserModel(familyMemberName: "grandmother", familyMemberImage: "Grandmother")
    ]
    @State var selectedItem: UserModel? = nil
    
    var body: some View {
        ScrollView {
            ZStack {
                ZStack {
                    ForEach(Array(familyNames.reversed().enumerated()), id: \.element.id) { idx, ele in
                        let correctIdx = (idx - familyNames.count + 1) * -1
                        
                        if correctIdx < 3 {
                            nameRow(name: ele)
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
                            nameRow(name: ele)
                                .offset(y: collapsed ? CGFloat(correctIdx) * 60 : 0)
                                .opacity(collapsed ? 1 : 0)
                                .padding(.horizontal, collapsed ? 0 : CGFloat(correctIdx + 1) * 10)
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
                
                if let selectedItem {
                    nameRow(name: selectedItem)
                        .onTapGesture {
                            withAnimation(.spring(dampingFraction: 0.7)) {
                                collapsed.toggle()
                            }
                        }
                }
            }
            .padding(.horizontal)
        }
        .onAppear() {
            if let first = familyNames.first {
                selectedItemPressed(item: first)
            }
        }
    }
    
    func selectedItemPressed(item: UserModel) {
        let temp = selectedItem
        selectedItem = item
        familyNames.removeAll { $0.name == item.name } // removes matching value
        if let temp {
            familyNames.append(temp)
        }
    }
    
    @ViewBuilder
    func nameRow(name: UserModel) -> some View {
        HStack {
            Image(name.image)
                .resizable()
                .frame(width: 33, height: 33)
            
            Text(name.name.capitalized)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color(hex: "#2E2E2E"))
            
            Spacer()
            
            Circle()
                .fill(.white)
                .frame(width: 14, height: 14)
                .padding(3)
                .background(
                    Circle()
                        .stroke(lineWidth: 0.5)
                        .foregroundStyle(Color(hex: "#B6B6B6"))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 0.5)
                .foregroundStyle(Color(hex: "#BAB8B8"))
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#EBEBEB"))
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
