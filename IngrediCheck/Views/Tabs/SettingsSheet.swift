import SwiftUI
import SimpleToast

struct SettingsSheet: View {
    
    @Environment(UserPreferences.self) var userPreferences
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) var appState
    @Environment(AuthController.self) var authController
    
    @State private var showInternalModeToast = false
    @State private var internalModeToastMessage = "Internal Mode Unlocked"

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
                    if authController.signedInWithApple || authController.signedInWithGoogle {
                        // Provider badge
                        if let providerDisplay = authController.currentSignInProviderDisplay {
                            HStack(spacing: 10) {
                                if authController.signedInWithApple {
                                    Image(systemName: "applelogo")
                                        .foregroundStyle(.primary)
                                } else {
                                    Image("google_logo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(providerDisplay.text)
                                        .font(.footnote)
                                        .fontWeight(.semibold)
                                    if let email = authController.displayableEmail, !email.isEmpty {
                                        Text(email)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                
                                // Provider-aware Sign out
                                SignoutButton()
                            }
                            .padding(.vertical, 2)
                        }

                        // Danger Zone
                        VStack(spacing: 8) {
                            Text("Danger Zone")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            DeleteAccountView(labelText: "Delete Data & Account")
                        }
                        .padding(.top, 6)
                    } else if authController.signedInAsGuest {
                        AccountUpgradeView()
                        DeleteAccountView(labelText: "Reset App State")
                    } else {
                        Text("Sign in to manage your account.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
                    if authController.isInternalUser {
                        Label {
                            Text("Internal Mode Enabled")
                                .foregroundStyle(.paletteAccent)
                        } icon: {
                            Image(systemName: "hammer")
                                .foregroundStyle(.paletteAccent)
                        }
                        .onTapGesture(count: 7) {
                            let disabled = authController.disableInternalMode()
                            if disabled {
                                internalModeToastMessage = "Internal Mode Disabled"
                                showInternalModeToast = false
                                showInternalModeToast = true
                            }
                        }
                    }
                    Label {
                        Text("IngrediCheck for iOS \(appVersion).(\(buildNumber))")
                    } icon: {
                        Image(systemName: "app")
                    }
                    .onTapGesture(count: 7) {
                        let unlocked = authController.enableInternalMode()
                        if unlocked {
                            internalModeToastMessage = "Internal Mode Unlocked"
                            showInternalModeToast = false
                            showInternalModeToast = true
                        }
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
        .simpleToast(
            isPresented: $showInternalModeToast,
            options: SimpleToastOptions(alignment: .top, hideAfter: 2)
        ) {
            InternalModeToastView(message: internalModeToastMessage)
        }
    }
    
    struct AccountUpgradeView: View {
        @Environment(AuthController.self) var authController
        @State private var showUpgradeError = false
        @State private var upgradeErrorMessage = ""

        var body: some View {
            Group {
                Text("Sign-in to avoid losing data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if authController.isUpgradingAccount {
                    HStack {
                        Spacer()
                        ProgressView("Signing in...")
                        Spacer()
                    }
                }

                Button {
                    Task {
                        await authController.upgradeCurrentAccount(to: .apple)
                    }
                } label: {
                    Label {
                        Text("Sign-in with Apple")
                    } icon: {
                        Image(systemName: "applelogo")
                    }
                }
                .disabled(authController.isUpgradingAccount)

                Button {
                    Task {
                        await authController.upgradeCurrentAccount(to: .google)
                    }
                } label: {
                    Label {
                        Text("Sign-in with Google")
                    } icon: {
                        Image("google_logo")
                    }
                }
                .disabled(authController.isUpgradingAccount)
            }
            .onChange(of: authController.accountUpgradeError?.localizedDescription ?? "", initial: false) { _, message in
                guard !message.isEmpty else {
                    return
                }
                upgradeErrorMessage = message
                showUpgradeError = true
            }
            .alert("Upgrade Failed", isPresented: $showUpgradeError) {
                Button("OK", role: .cancel) {
                    Task { @MainActor in
                        authController.accountUpgradeError = nil
                    }
                }
            } message: {
                Text(upgradeErrorMessage)
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

private struct InternalModeToastView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.paletteAccent)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 6, y: 2)
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
            HStack(spacing: 8) {
                Text("Sign out")
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .buttonBorderShape(.capsule)
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
