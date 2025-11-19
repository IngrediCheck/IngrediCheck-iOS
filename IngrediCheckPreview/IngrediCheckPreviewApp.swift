//
//  IngrediCheckPreviewApp.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haider on 30/09/25.
//

import SwiftUI

@main
struct IngrediCheckPreviewApp: App {
    
    init() {
        for family in UIFont.familyNames {
            print("Font family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("  \(name)")
            }
        }

    }
    
    var body: some Scene {
        WindowGroup {
            ProductDetailView(isPlaceholderMode: false)
                .environment(AppNavigationCoordinator())
                .preferredColorScheme(.light)
        }
    }
}
