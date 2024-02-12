import SwiftUI

struct HomeTab: View {
    
    @Environment(UserPreferences.self) var userPreferences
    @State private var newPreference: String = ""
    @FocusState var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Add your preference here", text: $newPreference)
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
                List {
                    ForEach(userPreferences.preferences, id: \.self) { preference in
                        Label(preference, systemImage: "hand.point.right")
                    }
                    .onDelete { offsets in
                        userPreferences.preferences.remove(atOffsets: offsets)
                    }
                }
                .listStyle(.plain)
                Divider()
                    .padding(.bottom, 5)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Your Dietary Preferences")
            .gesture(TapGesture().onEnded {
                isFocused = false
            })
        }
    }
}

#Preview {
    HomeTab()
}
