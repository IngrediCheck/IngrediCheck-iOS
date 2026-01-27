import SwiftUI

struct BulletView: View {
    var body: some View {
        Image(systemName: "circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 10, height: 10)
    }
}

enum ValidationResult {
    case idle
    case validating
    case success
    case failure(String)
}

@MainActor struct HomeTab: View {

    @FocusState var isFocused: Bool
    @State private var preferenceExamples = PreferenceExamples()

    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService
    @Environment(DietaryPreferences.self) var dp
    @Environment(UserPreferences.self) var userPreferences
    @Environment(MemojiStore.self) var memojiStore
    @Environment(AppNavigationCoordinator.self) var coordinator

    var body: some View {
        // Note: NavigationStack is provided by LoggedInRootView (Single Root NavigationStack)
        VStack {
            textInputField
            if dp.preferences.isEmpty && !isFocused {
                EmptyPreferencesView()
            } else {
                preferenceListView
            }
        }
        .onAppear {
            dp.refreshPreferences()
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
    
    private var validationStatus: some View {
        HStack(spacing: 5) {
            switch dp.validationResult {
            case .validating:
                Text("Thinking")
                    .foregroundStyle(.paletteAccent)
                ProgressView()
            case .failure(let string):
                Text(string)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
            case .idle, .success:
                EmptyView()
            }
            Spacer()
        }
        .font(.subheadline)
        .padding(.horizontal)
    }
    
    private var settingsButton: some View {
        Button {
            appState.navigate(to: .settings)
        } label: {
            Image(systemName: "gearshape")
        }
    }
    
    private var textInputField: some View {
        @Bindable var dp = dp
        func borderColor(for result: ValidationResult) -> Color {
            switch result {
            case .validating:
                return .paletteAccent
            case .failure:
                return .red
            case .success, .idle:
                return .clear
            }
        }
        return VStack(spacing: 5) {
            TextField(preferenceExamples.placeholder, text: $dp.newPreferenceText, axis: .vertical)
                .focused($isFocused)
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
                                .stroke(borderColor(for: dp.validationResult), lineWidth: 1)
                        }
                    }
                }
                .overlay(
                    HStack {
                        if !dp.newPreferenceText.isEmpty {
                            Button(action: {
                                dp.clearNewPreferenceText()
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
                .padding(.horizontal)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(action: {
                            dp.cancelInEditPreference()
                            isFocused = false
                        }, label: {
                            Text("Cancel")
                                .fontWeight(.bold)
                        })
                    }
                }
                .onChange(of: isFocused) { oldValue, newValue in
                    if newValue {
                        dp.inputActive()
                    }
                }
                .onEnter($of: $dp.newPreferenceText, isFocused: $isFocused) {
                    dp.inputComplete()
                }
            validationStatus
        }
        .padding(.vertical)
    }

    private var preferenceListView: some View {
        List {
            ForEach(dp.preferences) { preference in
                Label {
                    Text(LocalizedStringKey(preference.annotatedText))
                } icon: {
                    BulletView()
                        .foregroundStyle(.paletteAccent)
                }
                .listRowSeparatorTint(.paletteAccent)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = preference.text
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    Button {
                        dp.startEditPreference(preference: preference)
                        isFocused = true
                    } label: {
                        Label("Edit", systemImage: "square.and.pencil")
                    }
                    Button(role: .destructive) {
                        dp.deletePreference(preference: preference)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            dp.refreshPreferences()
        }
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
                if dp.preferences.isEmpty {
                    preferenceExamples.startAnimatingExamples()
                } else {
                    preferenceExamples.stopAnimatingExamples(isFocused: false)
                }
            }
        }
    }
}

struct EmptyPreferencesView: View {
        
    @State private var currentTabViewIndex = 0

    var body: some View {
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
                        Text(LocalizedStringKey("\"" + PreferenceExamples.examples[index] + ".\""))
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
}
