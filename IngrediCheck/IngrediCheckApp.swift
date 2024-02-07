import SwiftUI

@main
struct IngrediCheckApp: App {
    @State var webService = WebService()
    let authController = AuthController()
    var body: some Scene {
        WindowGroup {
            if let _ = authController.authEvent {
                if let _ = authController.session {
                    LoggedInRootView()
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
