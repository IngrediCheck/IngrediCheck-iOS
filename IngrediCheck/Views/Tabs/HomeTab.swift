import SwiftUI

struct BulletView: View {
    var body: some View {
        Image(systemName: "circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 10, height: 10)
    }
}

struct HomeTab: View {
    @Environment(UserPreferences.self) var userPreferences
    @State private var newPreference: String = ""
    @State private var placeholder: String = "Add your preference here"
    @State private var preferenceExamples = PreferenceExamples()
    @FocusState var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                TextField(preferenceExamples.placeholder, text: $newPreference, axis: .vertical)
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
                    .padding()
                    .focused(self.$isFocused)
                    .onEnter($of: $newPreference) {
                        if !newPreference.isEmpty {
                            withAnimation {
                                userPreferences.preferences.insert(newPreference, at: 0)
                            }
                            newPreference = ""
                        }
                    }
                    .onChange(of: isFocused) { oldValue, newValue in
                        if newValue {
                            preferenceExamples.stopAnimatingExamples(isFocused: true)
                        } else {
                            if userPreferences.preferences.isEmpty {
                                preferenceExamples.startAnimatingExamples()
                            } else {
                                preferenceExamples.stopAnimatingExamples(isFocused: false)
                            }
                        }
                    }
                List {
                    if userPreferences.preferences.isEmpty && !isFocused {
                        ForEach(preferenceExamples.preferences, id: \.self) { preference in
                            Label {
                                Text(preference)
                            } icon: {
                                BulletView()
                            }
                            .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(userPreferences.preferences, id: \.self) { preference in
                            Label {
                                Text(preference)
                            } icon: {
                                BulletView()
                                .foregroundStyle(.paletteAccent)
                            }
                        }
                        .onDelete { offsets in
                            userPreferences.preferences.remove(atOffsets: offsets)
                        }
                    }
                }
                .listStyle(.plain)
                Divider()
            }
            .animation(.linear, value: isFocused)
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
                preferenceExamples.stopAnimatingExamples(isFocused: false)
            }
        }
    }
}

#Preview {
    HomeTab()
}
