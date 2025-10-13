import SwiftUI

struct SettingsSheet: View {
    
    @Environment(UserPreferences.self) var userPreferences
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) var appState
    @Environment(AuthController.self) var authController

    var body: some View {
        @Bindable var userPreferences = userPreferences
        NavigationStack {
            Form {
                /*
                Section {
                    Picker("OCR Engine", selection: $userPreferences.ocrModel) {
                        Text("iOS").tag(OcrModel.iOSBuiltIn)
                        Text("Google").tag(OcrModel.googleMLKit)
                    }
                }
                */
                Section("Settings") {
                    Toggle("Start Scanning on App Start", isOn: $userPreferences.startScanningOnAppStart)
                }
                Section("Account") {
                    if authController.signedInWithApple {
                        SignoutButton()
                        DeleteAccountView(labelText: "Delete Data & Account")

                    }
                    if authController.signedInAsGuest {
                        DeleteAccountView(labelText: "Reset App State")
                    }
                    
                    if authController.signedInWithGoogle {
                        SignoutButton()
                        DeleteAccountView(labelText: "Delete Data & Account")
                    }
                }
                Section("About") {
                    NavigationLink(value: URL(string: "https://www.ingredicheck.app/about")!) {
                        Label {
                            Text("About me")
                        } icon: {
                            Image(systemName: "person.circle")
                        }
                    }
                    
                    NavigationLink {
                        TipJarView()
                    } label: {
                        Label {
                            Text("Tip Jar")
                        } icon: {
                            Image(systemName: "heart")
                        }
                    }

                    
                    NavigationLink(value: URL(string: "https://www.ingredicheck.app/about")!) {
                        Label {
                            Text("Help")
                        } icon: {
                            Image(systemName: "questionmark.circle")
                        }
                    }
                    NavigationLink(value: URL(string: "https://www.ingredicheck.app/terms-conditions")!) {
                        Label {
                            Text("Terms of Use")
                        } icon: {
                            Image(systemName: "book.pages")
                        }
                    }
                    NavigationLink(value: URL(string: "https://www.ingredicheck.app/privacy-policy")!) {
                        Label {
                            Text("Privacy Policy")
                        } icon: {
                            Image(systemName: "lock")
                        }
                    }
                    Label {
                        Text("IngrediCheck for iOS \(appVersion).(\(buildNumber))")
                    } icon: {
                        Image(systemName: "app")
                    }
                }
            }
            .navigationDestination(for: URL.self, destination: { url in
                WebView(url: url)
            })
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("SETTINGS")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                    }

                }
            }
        }
    }
    
    
    var appVersion: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return "0.0"
        }
        return version
    }
    
    var buildNumber: String {
        guard let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
            return "00"
        }
        return buildNumber
    }
}

struct DeleteAccountView: View {
    
    let labelText: String

    @Environment(AuthController.self) var authController
    @Environment(OnboardingState.self) var onboardingState
    @Environment(UserPreferences.self) var userPreferences
    @Environment(DietaryPreferences.self) var dietaryPreferences
    @Environment(AppState.self) var appState

    @State private var confirmationShown = false

    var body: some View {
        Button {
            confirmationShown = true
        } label: {
            Label {
                Text(labelText)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
            .foregroundStyle(.red)
        }
        .confirmationDialog(
            "Your Data cannot be recovered",
            isPresented: $confirmationShown,
            titleVisibility: .visible
        ) {
            Button("I Understand") {
                Task {
                    await authController.deleteAccount()
                    await MainActor.run {
                        appState.activeSheet = nil
                        appState.activeTab = .home
                        appState.feedbackConfig = nil
                        appState.listsTabState = ListsTabState()
                        onboardingState.clearAll()
                        userPreferences.clearAll()
                        dietaryPreferences.clearAll()
                    }
                }
            }
        }
    }
}

struct SignoutButton: View {

    @Environment(AuthController.self) var authController
    @Environment(OnboardingState.self) var onboardingState
    @Environment(UserPreferences.self) var userPreferences
    @Environment(DietaryPreferences.self) var dietaryPreferences
    @Environment(AppState.self) var appState

    var body: some View {
        Button {
            Task {
                await authController.signOut()
                await MainActor.run {
                    appState.activeSheet = nil
                    appState.activeTab = .home
                    appState.feedbackConfig = nil
                    appState.listsTabState = ListsTabState()
                    onboardingState.clearAll()
                    userPreferences.clearAll()
                    dietaryPreferences.clearAll()
                }
            }
        } label: {
            Label {
                Text("Sign out")
            } icon: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
            }
        }
    }
}

@MainActor struct SettingsTabContainer: View {
    @State private var userPreferences = UserPreferences()
    var body: some View {
        SettingsSheet()
            .environment(userPreferences)
    }
}

#Preview {
    SettingsTabContainer()
}
