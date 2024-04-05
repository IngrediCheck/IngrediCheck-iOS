import SwiftUI

@main @MainActor
struct IngrediCheckApp: App {
    @State var webService = WebService()
    @State private var userPreferences: UserPreferences = UserPreferences()
    @State private var appState = AppState()

    let authController = AuthController()

    var body: some Scene {
        WindowGroup {
            if let _ = authController.authEvent {
                if let _ = authController.session {
                    LoggedInRootView()
                        .environment(webService)
                        .environment(userPreferences)
                        .environment(appState)
                        .tint(.paletteAccent)
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
