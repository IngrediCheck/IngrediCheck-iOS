//
//  Temp.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 03/10/25.
//



import SwiftUI

struct DropdownMenuExample: View {
    @State private var isExpanded = false
    @State private var selectedItem: FamilyMember = FamilyMember(name: "Father", image: "Father")

    let familyMembers: [FamilyMember] = [
        FamilyMember(name: "Grandmother", image: "Grandmother"),
        FamilyMember(name: "Daughter", image: "Daughter"),
        FamilyMember(name: "Son", image: "Son"),
        FamilyMember(name: "Mother", image: "Mother"),
        FamilyMember(name: "Father", image: "Father")
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            VStack {
                Spacer()
                
                // Main content sheet
                VStack(spacing: 16) {
                    
                    // Dropdown field
                    Button {
                        withAnimation(.spring()) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Image(selectedItem.image)
                                .resizable()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                            Text(selectedItem.name)
                                .font(.headline)
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        }
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                    }
                    
                    // Other buttons
                    HStack {
                        Button("Random") {}
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                        
                        Button("Generate") {}
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .padding()
                .frame(height: 300)
                .background(Color.white)
                .cornerRadius(24)
                .shadow(radius: 10)
                
            }
            
            // Dropdown overlay (outside the sheet)
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(familyMembers) { member in
                        Button {
                            withAnimation {
                                selectedItem = member
                                isExpanded = false
                            }
                        } label: {
                            HStack {
                                Image(member.image)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                Text(member.name)
                                    .font(.body)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .shadow(radius: 8)
                .offset(y: -300) // <-- moves above sheet
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color(UIColor.systemGray4).opacity(0.3))
    }
}

struct FamilyMember: Identifiable {
    let id = UUID()
    let name: String
    let image: String
}

#Preview {
    DropdownMenuExample()
}

