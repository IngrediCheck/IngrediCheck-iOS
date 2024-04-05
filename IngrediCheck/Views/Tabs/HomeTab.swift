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
    @Environment(AppState.self) var appState
    @State private var newPreference: String = ""
    @State private var inEditPreference: String? = nil
    @State private var placeholder: String = "Add your preference here"
    @State private var preferenceExamples = PreferenceExamples()
    @FocusState var isFocused: Bool
    @State private var indexOfCurrentlyEditedPreference: Int = 0

    var body: some View {
        NavigationStack {
            VStack {
                TextField(preferenceExamples.placeholder, text: $newPreference, axis: .vertical)
                    .focused(self.$isFocused)
                    .padding()
                    .padding(.trailing)
                    .background {
                        Group {
                            if isFocused {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.clear)
                                    .stroke(Color.paletteAccent, lineWidth: 0.75)
                                    .shadow(color: Color.paletteAccent.opacity(1), radius: 20)
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Material.ultraThin)
                            }
                        }
                    }
                    .overlay(
                        HStack {
                            if !newPreference.isEmpty {
                                Button(action: {
                                    newPreference = ""
                                }) {
                                    Image(systemName: "multiply.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.vertical)
                        .padding(.horizontal, 7)
                        ,
                        alignment: .topTrailing
                    )
                    .padding()
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(action: {
                                if let inEditPreference {
                                    userPreferences.preferences.insert(inEditPreference, at: indexOfCurrentlyEditedPreference)
                                    newPreference = ""
                                }
                                inEditPreference = nil
                                indexOfCurrentlyEditedPreference = 0
                                isFocused = false
                            }, label: {
                                Text("Cancel")
                                    .fontWeight(.bold)
                            })
                        }
                    }
                    .onEnter($of: $newPreference, isFocused: $isFocused) {
                        if !newPreference.isEmpty {
                            withAnimation {
                                userPreferences.preferences.insert(newPreference, at: indexOfCurrentlyEditedPreference)
                                newPreference = ""
                            }
                            indexOfCurrentlyEditedPreference = 0
                            inEditPreference = nil
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
                            .listRowSeparatorTint(.paletteAccent)
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = preference
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                Button {
                                    print("edit tapped")
                                    indexOfCurrentlyEditedPreference =
                                        userPreferences.preferences.firstIndex(of: preference)!
                                    userPreferences.preferences.remove(at: indexOfCurrentlyEditedPreference)
                                    inEditPreference = preference
                                    newPreference = preference
                                    isFocused = true
                                } label: {
                                    Label("Edit", systemImage: "square.and.pencil")
                                }
                                Button(role: .destructive) {
                                    print("delete tapped")
                                    userPreferences.preferences.removeAll { $0 == preference }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        appState.activeSheet = .settings
                    }, label: {
//                        Image(systemName: appState.activeSheet == .settings ? "gearshape.fill" : "gearshape")
                        Image(systemName: "gearshape")
                    })
                }
            }
            .animation(.linear, value: isFocused)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Your Dietary Preferences")
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
