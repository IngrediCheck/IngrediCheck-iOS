import SwiftUI

struct SettingsTab: View {
    @Environment(UserPreferences.self) var userPreferences
    var body: some View {
        @Bindable var userPreferences = userPreferences
        NavigationStack {
            Form {
                Section {
                    Picker("OCR Engine", selection: $userPreferences.ocrModel) {
                        Text("iOS").tag(OcrModel.iOSBuiltIn)
                        Text("Google").tag(OcrModel.googleMLKit)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("SETTINGS")
        }
    }
}

struct SettingsTabContainer: View {
    @State private var userPreferences = UserPreferences()
    var body: some View {
        SettingsTab()
            .environment(userPreferences)
    }
}

#Preview {
    SettingsTabContainer()
}
