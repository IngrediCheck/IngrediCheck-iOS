//
//  EmptyStateView.swift
//  IngrediCheck
//
//  Created on 30/01/25.
//

import SwiftUI

struct EmptyStateView: View {
    let imageName: String
    let title: String
    let description: [String]
    let buttonTitle: String?
    let buttonAction: (() -> Void)?
    
    init(
        imageName: String,
        title: String,
        description: [String],
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil
    ) {
        self.imageName = imageName
        self.title = title
        self.description = description
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
    }
    
    var body: some View {
        VStack {
            VStack {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                
                VStack(spacing: 0) {
                    Text(title)
                        .font(ManropeFont.bold.size(16))
                        .foregroundStyle(.grayScale150)
                    
                    ForEach(description, id: \.self) { line in
                        Text(line)
                            .font(ManropeFont.regular.size(13))
                            .foregroundStyle(.grayScale100)
                            .multilineTextAlignment(.center)
                    }
                    
                    if let buttonTitle = buttonTitle, let buttonAction = buttonAction {
                        Button {
                            buttonAction()
                        } label: {
                            GreenCapsule(
                                title: buttonTitle,
                                width: 159,
                                height: 52,
                                takeFullWidth: false,
                                labelFont: ManropeFont.bold.size(16)
                            )
                        }
                        .padding(.top, 24)
                        .buttonStyle(.plain)
                    }
                }
                .offset(y: -UIScreen.main.bounds.height * 0.2)
            }
        }
    }
}

#Preview("With Button") {
    EmptyStateView(
        imageName: "history-emptystate",
        title: "No Scans !",
        description: [
            "Your recent scans will appear here once",
            "you start scanning products."
        ],
        buttonTitle: "Start Scanning",
        buttonAction: {
            print("Start scanning tapped")
        }
    )
}

#Preview("Without Button") {
    EmptyStateView(
        imageName: "history-emptystate",
        title: "No Items",
        description: [
            "There are no items to display."
        ]
    )
}
