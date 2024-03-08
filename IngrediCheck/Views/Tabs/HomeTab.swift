import SwiftUI

struct HomeTab: View {
    @Environment(UserPreferences.self) var userPreferences
    @State private var newPreference: String = ""
    @State private var placeholder: String = "Add your preference here"
    @State private var preferenceExamples = PreferenceExamples()
    @FocusState var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                TextField(preferenceExamples.placeholder, text: $newPreference)
                    .padding()
                    .background(.ultraThinMaterial, in: .capsule)
                    .padding()
                    .focused(self.$isFocused)
                    .onSubmit {
                        if !newPreference.isEmpty {
                            userPreferences.preferences.insert(newPreference, at: 0)
                            newPreference = ""
                        }
                    }
                    .onChange(of: isFocused) { oldValue, newValue in
                        if newValue {
                            preferenceExamples.stopAnimatingExamples()
                        } else {
                            preferenceExamples.startAnimatingExamples()
                        }
                    }
                List {
                    if userPreferences.preferences.isEmpty && !isFocused {
                        ForEach(preferenceExamples.preferences, id: \.self) { preference in
                            Label(preference, systemImage: "hand.point.right")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(userPreferences.preferences, id: \.self) { preference in
                            Label(preference, systemImage: "hand.point.right")
                        }
                        .onDelete { offsets in
                            userPreferences.preferences.remove(atOffsets: offsets)
                        }
                    }
                }
                .listStyle(.plain)
                Divider()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Your Dietary Preferences")
            .gesture(TapGesture().onEnded {
                isFocused = false
            })
            .onAppear {
                if userPreferences.preferences.isEmpty {
                    preferenceExamples.startAnimatingExamples()
                }
            }
            .onDisappear {
                preferenceExamples.stopAnimatingExamples()
            }
        }
    }
}

#Preview {
    HomeTab()
}
