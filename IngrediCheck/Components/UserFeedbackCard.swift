//
//  UserFeedbackCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 08/10/25.
//

import SwiftUI

struct UserFeedbackCard: View {
    
    /// Current selected star rating (0–5). 0 means “not rated yet”.
    @State private var rating: Int = 0
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Microcopy.text(Microcopy.Key.Feedback.Card.titleLine1)
                    Microcopy.text(Microcopy.Key.Feedback.Card.titleLine2)
                    Microcopy.text(Microcopy.Key.Feedback.Card.titleLine3)
                }
                .font(ManropeFont.semiBold.size(16))
                    Spacer()
                Image("feedbackimg")
                    .frame(width: 55, height: 55)
            }
            
            VStack(alignment: .leading) {
                Microcopy.text(Microcopy.Key.Feedback.Card.subtitle)
                    .font(ManropeFont.light.size(12))
                    .foregroundColor(Color(hex: "#A6A6A6"))
                
                Divider()
            }
            
            // Star rating row
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { index in
                    Button {
                        // Tapping a star sets the rating to that value.
                        // All stars up to this index become “active”.
                        rating = index
                        if let writeURL = URL(string: "itms-apps://apps.apple.com/app/id6477521615?action=write-review") {
                            openURL(writeURL) { accepted in
                                if !accepted {
                                    if let webURL = URL(string: "https://apps.apple.com/us/app/ingredicheck-grocery-scanner/id6477521615?see-all=reviews&platform=iphone") {
                                        openURL(webURL)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image("star-rating")
                            .renderingMode(.template)
                            .foregroundColor(
                                index <= rating
                                    ? Color(hex: "#FFD860")
                                    : .grayScale90  // default / inactive color
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(height: UIScreen.main.bounds.height * 0.18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.grayScale10)
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(lineWidth: 0.25)
                .foregroundStyle(.grayScale60)
        )
    }
}

#Preview {
    ZStack {
        //        Color(.gray).opacity(0.2).ignoresSafeArea()
        UserFeedbackCard()
    }
}
