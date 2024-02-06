import SwiftUI

struct HomeTab: View {
    
    @Environment(UserPreferences.self) var userPreferences
    @State private var newPreference: String = ""
    @FocusState var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Add your preference here", text: $newPreference)
                    .frame(height: 60)
                    .padding(5)
                    .cornerRadius(15)
                    .shadow(radius: isFocused ? 1 : 0)
                    .onSubmit {
                        if !newPreference.isEmpty {
                            userPreferences.preferences.insert(newPreference, at: 0)
                            newPreference = ""
                        }
                    }
                    .focused(self.$isFocused)
                    .multilineTextAlignment(.center)
                    .padding()
                List {
                    ForEach(userPreferences.preferences, id: \.self) { preference in
                        Text(preference)
                    }
                    .onDelete { offsets in
                        userPreferences.preferences.remove(atOffsets: offsets)
                    }
                }
                .listStyle(.plain)
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
