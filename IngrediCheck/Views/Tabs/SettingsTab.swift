import SwiftUI

struct SettingsTab: View {
    @Environment(UserPreferences.self) var userPreferences
    var body: some View {
        @Bindable var userPreferences = userPreferences
        NavigationStack {
            VStack {
                Form {
                    Section {
                        Picker("OCR Engine", selection: $userPreferences.ocrModel) {
                            Text("iOS").tag(OcrModel.iOSBuiltIn)
                            Text("Google").tag(OcrModel.googleMLKit)
                        }
                    }
                }
                Text("App Version \(appVersion).(\(buildNumber))")
                    .font(.footnote)
                    .padding(.bottom, 10)
                Divider()
                    .padding(.bottom, 5)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("SETTINGS")
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
