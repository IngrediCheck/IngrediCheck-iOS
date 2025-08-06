//
//  ColaboratorCard.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 05/08/25.
//

import SwiftUI

struct ColaboratorCard: View {
    @State var noOfPeople: Int = 1
    @State var showDetails: Bool = false
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 5) {
                Circle()
                    .frame(width: 24, height: 24)
                
                Text("Collaborator")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                
                Circle()
                    .frame(width: 2, height: 2)
                    .foregroundStyle(.gray)
                
                Text("\(noOfPeople) people")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            
            if showDetails {
                Text("Despite its importance, the ocean faces increasing threats from pollution, overfishing, and climate change. Protecting this vital resource is essential not just for marine life, but for the health and survival of all life on Earth.")
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.gray.opacity(0.2))
        .cornerRadius(8)
        .onTapGesture {
            showDetails.toggle()
        }
        .animation(.easeInOut, value: showDetails)
    }
}

#Preview {
    ColaboratorCard()
}
