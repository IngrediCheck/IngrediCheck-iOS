import SwiftUI

struct BulletView: View {
    var body: some View {
        Image(systemName: "circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 10, height: 10)
    }
}

@MainActor struct HomeTab: View {
    @State private var newPreference: String = ""
    @State private var inEditPreference: String? = nil
    @State private var placeholder: String = "Add your preference here"
    @State private var preferenceExamples = PreferenceExamples()
    @FocusState var isFocused: Bool
    @State private var indexOfCurrentlyEditedPreference: Int = 0

    @Environment(UserPreferences.self) var userPreferences
    @Environment(AppState.self) var appState

    var body: some View {
        NavigationStack {
            VStack {
                textInputField
                if userPreferences.preferences.isEmpty && !isFocused {
                    emptyView
                } else {
                    preferenceListView
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    settingsButton
                }
            }
            .animation(.linear, value: isFocused)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Your Dietary Preferences")
        }
    }

    @State private var currentTabViewIndex = 0

    private var emptyView: some View {
        VStack {
            VStack {
                Image("EmptyPreferenceList")
                    .resizable()
                    .scaledToFit()
                Text("You don't have any dietary preferences entered yet")
                    .font(.subheadline)
                    .fontWeight(.light)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray)
                    .padding(.top)
            }
            .frame(width: UIScreen.main.bounds.width / 2)
            Spacer()
            VStack(spacing: 8) {
                Text("Try the following")
                    .foregroundStyle(.gray)
                TabView(selection: $currentTabViewIndex.animation()) {
                    ForEach(0 ..< PreferenceExamples.examples.count, id:\.self) { index in
                        Text("\"" + PreferenceExamples.examples[index] + ".\"")
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.paletteAccent)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: UIScreen.main.bounds.width / 3)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.paletteAccent.opacity(0.1))
                }
                .padding(.horizontal)
                
                ThreeDotsIndexView(
                    numberOfPages: PreferenceExamples.examples.count,
                    currentIndex: currentTabViewIndex
                )
            }
            Spacer()
        }
    }
    
    private var settingsButton: some View {
        Button(action: {
            appState.activeSheet = .settings
        }, label: {
            Image(systemName: "gearshape")
        })
    }
    
    private var textInputField: some View {
        TextField(preferenceExamples.placeholder, text: $newPreference, axis: .vertical)
            .focused(self.$isFocused)
            .padding()
            .padding(.trailing)
            .background {
                Group {
                    if isFocused {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.clear)
                            .stroke(Color.paletteAccent, lineWidth: 1)
                            .shadow(color: Color.paletteAccent.opacity(1), radius: 20)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
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
    }
    
    private var preferenceListView: some View {
        List {
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
        .listStyle(.plain)
    }
    
    private var preferenceExamplesView: some View {
        List {
            ForEach(preferenceExamples.preferences, id: \.self) { preference in
                Label {
                    Text(preference)
                } icon: {
                    BulletView()
                }
                .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .onAppear {
            preferenceExamples.startAnimatingExamples()
        }
        .onDisappear {
            preferenceExamples.stopAnimatingExamples(isFocused: false)
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
    }
}

#Preview {
    HomeTab()
}
