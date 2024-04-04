import SwiftUI

struct SettingsSheet: View {
    
    @Environment(UserPreferences.self) var userPreferences
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) var appState
    
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
                Section("About") {
                    NavigationLink(value: URL(string: "https://wikipedia.org")!) {
                        Label {
                            Text("About me")
                        } icon: {
                            Image(systemName: "person.circle")
                        }
                    }
                    NavigationLink(value: URL(string: "https://wikipedia.org")!) {
                        Label {
                            Text("Help")
                            // todo
                        } icon: {
                            Image(systemName: "questionmark.circle")
                        }
                    }
                    NavigationLink(value: URL(string: "https://wikipedia.org")!) {
                        Label {
                            Text("Terms of Use")
                            // todo
                        } icon: {
                            Image(systemName: "book.pages")
                        }
                    }
                    NavigationLink(value: URL(string: "https://wikipedia.org")!) {
                        Label {
                            Text("Privacy Policy")
                            // todo
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
