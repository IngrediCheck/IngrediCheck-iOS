//
//  ShouldIEatApp.swift
//  ShouldIEat
//
//  Created by sanket patel on 8/28/23.
//

import SwiftUI

@main
struct ShouldIEatApp: App {
    @State var webService = WebService()
    let authController = AuthController()
    var body: some Scene {
        WindowGroup {
            if let _ = authController.authEvent {
                if let _ = authController.session {
                    ContentView()
                        .environment(webService)
                } else {
                    Text("Sign-in failed")
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
