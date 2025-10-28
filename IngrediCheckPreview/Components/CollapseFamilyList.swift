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
        UserModel(familyMemberName: "Grandfather", familyMemberImage: "image-bg3"),
        UserModel(familyMemberName: "Grandmother", familyMemberImage: "image-bg2"),
        UserModel(familyMemberName: "Daughter", familyMemberImage: "image-bg5"),
        UserModel(familyMemberName: "Brother", familyMemberImage: "image-bg4")
    ]
    @State var selectedItem: UserModel? = nil
    
    var body: some View {
        ScrollView {
            ZStack {
                ZStack {
                    ForEach(Array(familyNames.reversed().enumerated()), id: \.element.id) { idx, ele in
                        let correctIdx = (idx - familyNames.count + 1) * -1
                        
                        if correctIdx < 3 {
                            nameRow(name: ele, isSelected: false)
                                .offset(y: collapsed ? CGFloat(correctIdx) * 70 : CGFloat(correctIdx * 8))
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
                            nameRow(name: ele, isSelected: false)
                                .offset(y: collapsed ? CGFloat(correctIdx) * 70 : 0)
                                .opacity(collapsed ? 1 : 0)
//                                .padding(.horizontal, collapsed ? 0 : CGFloat(correctIdx + 1) * 10)
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
                .offset(y: collapsed ? 70 : 10)
                
                if let selectedItem {
                    nameRow(name: selectedItem, isSelected: true)
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
    func nameRow(name: UserModel, isSelected: Bool) -> some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(Color(hex: "F9F9F9"))
                    
                    Image(name.image)
                        .resizable()
                        .frame(width: 30, height: 30)
                        .shadow(color: Color(hex: "DEDDDD"), radius: 3.5, x: 0, y: 0)
                }
                
                Text(name.name)
                    .font(ManropeFont.medium.size(14))
                    .foregroundStyle(.grayScale150)
            }
            
            Spacer()
            
            Circle()
                .stroke(lineWidth: 0.5)
                .foregroundStyle(isSelected ? .primary400 : .grayScale60)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(isSelected ? .primary500 : Color(hex: "FFFFFF"))
                        .shadow(color: Color(hex: "B5B5B5").opacity(0.4), radius: 5, x: 0, y: 0)
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 19)
                .stroke(lineWidth: 0.5)
                .foregroundStyle(.grayScale80)
        )
        .background(
            RoundedRectangle(cornerRadius: 19)
                .fill(.grayScale10)
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
