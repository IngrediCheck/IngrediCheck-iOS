//
//  ShouldIEatApp.swift
//  ShouldIEat
//
//  Created by sanket patel on 8/28/23.
//

import SwiftUI

@main
struct ShouldIEatApp: App {
    let authController = AuthController()
    var body: some Scene {
        WindowGroup {
            if let authEvent = authController.authEvent {
                if authEvent != .signedOut {
                    ContentView()
                } else {
                    ProgressView()
                }
            } else {
                ProgressView()
                    .onAppear {
                        authController.initialize()
                    }
            }
        }
    }
}
