import SwiftUI
import SimpleToast

struct SettingsSheet: View {
    
    @Environment(UserPreferences.self) var userPreferences
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) var appState
    @Environment(AuthController.self) var authController
    @Environment(FamilyStore.self) var familyStore
    @Environment(\.openURL) var openURL
    
    @State private var showInternalModeToast = false
    @State private var internalModeToastMessage = "Internal Mode Unlocked"
    @Environment(WebService.self) var webService
    @State private var settingsFeedbackData = FeedbackData()
    @State private var showFeedbackToast = false
    @State private var primaryMemberName: String = ""
    @FocusState private var isEditingPrimaryName: Bool
    @State private var isFeedbackPresented = false
    
    // Binding helper to avoid local @Bindable in body
    private var startScanningOnAppStartBinding: Binding<Bool> {
        Binding(
            get: { userPreferences.startScanningOnAppStart },
            set: { userPreferences.startScanningOnAppStart = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sticky Header Section
            VStack(spacing: 24) {
                // Top bar with back chevron and title (effective 12pt horizontal padding)
                HStack(spacing: 8) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.grayScale150)
                    }
                    Text("Profile & Settings")
                        .font(NunitoFont.bold.size(18))
                        .foregroundStyle(.grayScale150)
                    Spacer()
                }
                .padding(.horizontal, -8)
                .padding(.top, 8)

                // Profile Image and Name Header
                VStack(spacing: 8) {
                    ProfileCard(isProfileCompleted: true)
                        .frame(width: 72, height: 72)
                        .overlay(alignment: .bottomTrailing) {
                            Circle()
                                .fill(.white)
                                .frame(width: 24, height: 24)
                                .overlay(Image("pen-line").resizable().frame(width: 14, height: 14))
                                .offset(x: -6, y: -6)
                        }
                    nameEditField()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24) // Spacing from Header to the start of scrolling content

            // Scrolling Content Section
            ScrollView {
                VStack(spacing: 24) {
                    // Account
                    VStack(spacing: 8) {
                        Text("ACCOUNT")
                            .font(ManropeFont.semiBold.size(14))
                            .foregroundStyle(Color(hex: "#9EA19B"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                        if authController.session != nil && !authController.signedInAsGuest {
                            accountSignedInCard()
                        } else {
                            accountGuestCard()
                        }
                    }

                    // Settings
                    VStack(spacing: 8) {
                        Text("SETTINGS")
                            .font(ManropeFont.semiBold.size(14))
                            .foregroundStyle(Color(hex: "#9EA19B"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                        sectionCard {
                            HStack {
                                Text("Start Scanning on App Start")
                                    .font(NunitoFont.medium.size(16))
                                    .foregroundStyle(.grayScale150)
                                Spacer()
                                Toggle("", isOn: startScanningOnAppStartBinding)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 8)
                        }

                        sectionCard {
                            VStack(spacing: 0) {
                                settingsRow(icon: "create-family-icon", title: (familyStore.family != nil ? "Manage Family" : "Create Family"), iconColor: Color(hex: "#75990E")) {
                                    // TODO: wire navigation
                                }
                                Divider()
                                settingsRow(icon: "pen-line", title: "Food Notes", iconColor: Color(hex: "#75990E")) {
                                    // TODO: wire navigation
                                }
                            }
                        }
                    }

                    // About
                    VStack(spacing: 8) {
                        Text("ABOUT")
                            .font(ManropeFont.semiBold.size(14))
                            .foregroundStyle(Color(hex: "#9EA19B"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                        sectionCard {
                            NavigationLink {
                                WebView(url: URL(string: "https://www.ingredicheck.app/about")!)
                            } label: {
                                rowContent(image: Image("About-Me"), title: "About me")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Support us
                    VStack(spacing: 8) {
                        Text("SUPPORT US")
                            .font(ManropeFont.semiBold.size(14))
                            .foregroundStyle(Color(hex: "#9EA19B"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                        sectionCard {
                            Button {
                                isFeedbackPresented = true
                            } label: { rowContent(image: Image("Feedback-icon"), title: "Feedback") }
                            .buttonStyle(.plain)
                            Divider()
                            Button {
                                if let url = URL(string: "https://www.ingredicheck.app") { openURL(url) }
                            } label: { rowContent(image: Image("share"), title: "Share us", iconColor: Color(hex: "#75990E")) }
                            .buttonStyle(.plain)
                            Divider()
                            NavigationLink { TipJarView() } label: { rowContent(image: Image("Tip-Jar-icon"), title: "Tip Jar") }
                            .buttonStyle(.plain)
                        }
                    }

                    // Others
                    VStack(spacing: 8) {
                        Text("OTHERS")
                            .font(ManropeFont.semiBold.size(14))
                            .foregroundStyle(Color(hex: "#9EA19B"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                        sectionCard {
                            NavigationLink {
                                WebView(url: URL(string: "https://www.ingredicheck.app/about")!)
                            } label: { rowContent(image: Image("Help-icon"), title: "Help") }
                            .buttonStyle(.plain)
                            Divider()
                            NavigationLink {
                                WebView(url: URL(string: "https://www.ingredicheck.app/terms-conditions")!)
                            } label: { rowContent(image: Image("Terms-of-use"), title: "Terms of use") }
                            .buttonStyle(.plain)
                            Divider()
                            NavigationLink {
                                WebView(url: URL(string: "https://www.ingredicheck.app/privacy-policy")!)
                            } label: { rowContent(image: Image("Privacy-polices"), title: "Privacy policy") }
                            .buttonStyle(.plain)
                            Divider()
                            if authController.isInternalUser { rowContent(image: Image("Internal-Mode"), title: "Internal Mode Enabled") ; Divider() }
                            Button {
                                Task {
                                    do {
                                        _ = try await webService.markDeviceInternal(deviceId: authController.deviceId)
                                        await MainActor.run {
                                            authController.setInternalUser(true)
                                            internalModeToastMessage = "Internal Mode Unlocked"
                                            showInternalModeToast = false
                                            showInternalModeToast = true
                                        }
                                    } catch {
                                        print("Failed to mark device internal: \(error)")
                                    }
                                }
                            } label: { rowContent(image: Image("LogoGreen"), title: "IngrediCheck for iOS \(appVersion).(\(buildNumber))") }
                            .buttonStyle(.plain)
                        }
                    }

                    // Danger
                    VStack(spacing: 12) {
                        sectionCard {
                            if authController.session != nil && !authController.signedInAsGuest {
                                DeleteAccountView(labelText: "Delete Data & Account").padding(16)
                            } else {
                                ResetAppStateView(labelText: "Reset App State").padding(16)
                            }
                        }
                    }
                    .padding(.top, 24)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isFeedbackPresented) {
            FeedbackView(
                feedbackData: $settingsFeedbackData,
                feedbackCaptureOptions: .feedbackOnly,
                onSubmit: { showFeedbackToast = true }
            )
            .environment(userPreferences)
        }
        .onAppear {
            // 1) Prefill immediately from whatever is already in memory to avoid flicker/lag
            primaryMemberName = familyStore.family?.selfMember.name
                ?? familyStore.pendingSelfMember?.name
                ?? "Ritika Raj"

            // 2) Load family fresh in the background and update if it changes
            Task {
                await familyStore.loadCurrentFamily()
                await MainActor.run {
                    if let updated = familyStore.family?.selfMember.name ?? familyStore.pendingSelfMember?.name {
                        primaryMemberName = updated
                    }
                }
            }

            // 3) Check internal mode concurrently; do not block UI/name
            Task {
                do {
                    let isInternal = try await webService.isDeviceInternal(deviceId: authController.deviceId)
                    await MainActor.run { authController.setInternalUser(isInternal) }
                } catch {
                    print("Failed to check device internal status: \(error)")
                }
            }
        }
        // Keep name in sync when FamilyStore finishes loading or changes,
        // but do not override while the user is editing.
        .onChange(of: (familyStore.family?.selfMember.name ?? familyStore.pendingSelfMember?.name ?? "")) { _, newValue in
            guard !newValue.isEmpty, !isEditingPrimaryName else { return }
            if primaryMemberName != newValue { primaryMemberName = newValue }
        }
        .simpleToast(
            isPresented: $showInternalModeToast,
            options: SimpleToastOptions(alignment: .top, hideAfter: 2)
        ) {
            InternalModeToastView(message: internalModeToastMessage)
        }
    }
    
    // MARK: - Header name edit
    @ViewBuilder
    private func nameEditField() -> some View {
        HStack(spacing: 12) {
            TextField("", text: $primaryMemberName)
                .font(NunitoFont.semiBold.size(22))
                .foregroundStyle(Color(hex: "#303030"))
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .focused($isEditingPrimaryName)
                .submitLabel(.done)
                .onSubmit { commitPrimaryName() }
            Image("pen-line")
                .resizable()
                .frame(width: 12, height: 12)
                .foregroundStyle(.grayScale100)
                .onTapGesture { isEditingPrimaryName = true }
        }
        .padding(.horizontal, 20)
        .frame(minWidth: 144)
        .frame(maxWidth: 335)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "#E3E3E3"), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .fixedSize(horizontal: true, vertical: false)
        .padding(.top,10)
        .onTapGesture { isEditingPrimaryName = true }
        .onChange(of: isEditingPrimaryName) { _, editing in
            if !editing { commitPrimaryName() }
        }
    }
    
    private func commitPrimaryName() {
        let trimmed = primaryMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { @MainActor in
            if let family = familyStore.family {
                var me = family.selfMember
                guard me.name != trimmed else { return }
                me.name = trimmed
                await familyStore.editMember(me)
            } else if familyStore.pendingSelfMember != nil {
                if familyStore.pendingSelfMember?.name != trimmed {
                    familyStore.updatePendingSelfMemberName(trimmed)
                }
            }
        }
    }
    
    // MARK: - Section Card wrapper
    @ViewBuilder
    func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 0.75)
                .foregroundStyle(Color(hex: "#EEEEEE"))
        )
    }
    
    // MARK: - Rows
    @ViewBuilder
    func settingsRow(icon: String, title: String, iconColor: Color = .grayScale150, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(NunitoFont.medium.size(16))
                    .foregroundStyle(.grayScale150)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.grayScale150)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    func rowContent(systemIcon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemIcon)
                .frame(width: 20, height: 20)
            Text(title)
                .font(NunitoFont.medium.size(16))
                .foregroundStyle(.grayScale150)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 24, height: 24)
                .foregroundStyle(.grayScale150)
        }
        .padding( 12)
        
    }
    
    @ViewBuilder
    func rowContent(image: Image, title: String, iconColor: Color = .grayScale150) -> some View {
        HStack(spacing: 8) {
            image
                .resizable()
                .renderingMode(.template)
                .frame(width: 20, height: 20)
                .foregroundStyle(iconColor)
            Text(title)
                .font(NunitoFont.medium.size(16))
                .foregroundStyle(.grayScale150)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 24, height: 24)
                .foregroundStyle(.grayScale150)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Account Cards
    @ViewBuilder
    func accountGuestCard() -> some View {
        sectionCard {
            VStack(spacing: 12) {
                Text("      Sign-in to avoid losing data")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                    Button {
                        Task { await authController.upgradeCurrentAccount(to: .google) }
                    } label: {
                        HStack(spacing: 8) {
                            Image("google_logo")
                                .resizable()
                                .frame(width: 18, height: 18)
                            Text("Google")
                                .font(NunitoFont.semiBold.size(14))
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#F7F7F7"), in: .capsule)
                    //   .overlay(Capsule().stroke(lineWidth: 1.5).foregroundStyle(Color(hex: "91B640")))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        Task { await authController.upgradeCurrentAccount(to: .apple) }
                    } label: {
                        HStack(spacing: 8) {
                            Image("apple_logo")
                                .resizable()
                                .frame(width: 18, height: 18)
                            Text("Apple")
                                .font(NunitoFont.semiBold.size(14))
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#F7F7F7") , in: .capsule)
                     // .overlay(Capsule().stroke(lineWidth: 1.5).foregroundStyle(Color(hex: "91B640")))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    @ViewBuilder
    func accountSignedInCard() -> some View {
        sectionCard {
            HStack(spacing: 12) {
                if authController.signedInWithApple {
                    Image(systemName: "applelogo")
                        .frame(width: 22.96, height: 23.27)
                } else if authController.signedInWithGoogle {
                    Image("google_logo").resizable()
                        .frame(width: 22.96, height: 23.27)
                } else {
                    Image(systemName: "person.circle")
                        .frame(width: 22.96, height: 23.27)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(authController.currentSignInProviderDisplay?.text ?? "Signed in")
                        .font(ManropeFont.bold.size(12))
                        .foregroundStyle(.grayScale150)
                    if let email = authController.displayableEmail {
                        Text(email)
                            .font(ManropeFont.medium.size(12))
                            .foregroundStyle(.grayScale110)
                            .lineLimit(1)
                            
                    }
                }
                Spacer()
                SignoutButton()
            }
            .padding(16)
            .background(Color(hex: "#F7F7F7"))
            .cornerRadius(24)
        }
    }
    
    struct AccountUpgradeView: View {
        @Environment(AuthController.self) var authController
        @State private var showUpgradeError = false
        @State private var upgradeErrorMessage = ""

        var body: some View {
            Group {
                Text("Sign-in to avoid losing data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if authController.isUpgradingAccount {
                    HStack {
                        Spacer()
                        ProgressView("Signing in...")
                        Spacer()
                    }
                }

                Button {
                    Task {
                        await authController.upgradeCurrentAccount(to: .apple)
                    }
                } label: {
                    Label {
                        Text("Sign-in with Apple")
                    } icon: {
                        Image(systemName: "applelogo")
                    }
                }
                .disabled(authController.isUpgradingAccount)

                Button {
                    Task {
                        await authController.upgradeCurrentAccount(to: .google)
                    }
                } label: {
                    Label {
                        Text("Sign-in with Google")
                    } icon: {
                        Image("google_logo")
                    }
                }
                .disabled(authController.isUpgradingAccount)
            }
            .onChange(of: authController.accountUpgradeError?.localizedDescription ?? "", initial: false) { _, message in
                guard !message.isEmpty else {
                    return
                }
                upgradeErrorMessage = message
                showUpgradeError = true
            }
            .alert("Upgrade Failed", isPresented: $showUpgradeError) {
                Button("OK", role: .cancel) {
                    Task { @MainActor in
                        authController.accountUpgradeError = nil
                    }
                }
            } message: {
                Text(upgradeErrorMessage)
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

struct DeleteAccountView: View {
    
    let labelText: String

    @Environment(\.dismiss) var dismiss
    @Environment(AuthController.self) var authController
    @Environment(OnboardingState.self) var onboardingState
    @Environment(UserPreferences.self) var userPreferences
    @Environment(DietaryPreferences.self) var dietaryPreferences
    @Environment(AppState.self) var appState

    @State private var confirmationShown = false

    var body: some View {
        Button {
            confirmationShown = true
        } label: {
                    Label {
                Text(labelText)
                    .font(NunitoFont.medium.size(16))
                   
            } icon: {
                Image("Delete-icon")
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            .foregroundStyle(Color(hex: "#F04438"))
        }
        .confirmationDialog(
            "Your Data cannot be recovered",
            isPresented: $confirmationShown,
            titleVisibility: .visible
        ) {
            Button("I Understand") {
                Task {
                    await authController.deleteAccount()
                    await MainActor.run {
                        appState.activeSheet = nil
                        appState.activeTab = .home
                        appState.feedbackConfig = nil
                        appState.listsTabState = ListsTabState()
                        onboardingState.clearAll()
                        userPreferences.clearAll()
                        dietaryPreferences.clearAll()
                        
                        dismiss()
                        NotificationCenter.default.post(
                            name: Notification.Name("AppDidReset"),
                            object: nil
                        )
                    }
                }
            }
        }
    }
}

struct ResetAppStateView: View {

    let labelText: String

    @Environment(\.dismiss) var dismiss
    @Environment(AuthController.self) var authController
    @Environment(OnboardingState.self) var onboardingState
    @Environment(UserPreferences.self) var userPreferences
    @Environment(DietaryPreferences.self) var dietaryPreferences
    @Environment(AppState.self) var appState

    @State private var confirmationShown = false

    var body: some View {
        Button {
            confirmationShown = true
        } label: {
            Label {
                Text(labelText)
                    .font(NunitoFont.medium.size(16))
            } icon: {
                Image("Reset-icon")
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            .foregroundStyle(Color(hex: "#F04438"))
        }
        .confirmationDialog(
            "This will sign you out and reset the app",
            isPresented: $confirmationShown,
            titleVisibility: .visible
        ) {
            Button("Reset") {
                Task {
                    await authController.resetForAppReset()
                    await MainActor.run {
                        appState.activeSheet = nil
                        appState.activeTab = .home
                        appState.feedbackConfig = nil
                        appState.listsTabState = ListsTabState()
                        onboardingState.clearAll()
                        userPreferences.clearAll()
                        dietaryPreferences.clearAll()
                        UserDefaults.standard.removeObject(forKey: "hasLaunchedOncePreviewFlow")
                        dismiss()
                        NotificationCenter.default.post(
                            name: Notification.Name("AppDidReset"),
                            object: nil
                        )
                    }
                }
            }
        }
    }
}

private struct InternalModeToastView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.paletteAccent)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 6, y: 2)
    }
}

struct SignoutButton: View {

    @Environment(AuthController.self) var authController
    @Environment(\.dismiss) var dismiss
    @Environment(OnboardingState.self) var onboardingState
    @Environment(UserPreferences.self) var userPreferences
    @Environment(DietaryPreferences.self) var dietaryPreferences
    @Environment(AppState.self) var appState

    var body: some View {
        Button {
            Task {
                await authController.resetForAppReset()
                await MainActor.run {
                    appState.activeSheet = nil
                    appState.activeTab = .home
                    appState.feedbackConfig = nil
                    appState.listsTabState = ListsTabState()
                    onboardingState.clearAll()
                    userPreferences.clearAll()
                    dietaryPreferences.clearAll()
                    
                    dismiss()
                    NotificationCenter.default.post(
                        name: Notification.Name("AppDidReset"),
                        object: nil
                    )
                }
            }
        } label: {
            ZStack {
                Text("Sign out")
                    .font(NunitoFont.semiBold.size(12))
                    .foregroundStyle(.grayScale10)
            }
            .frame(width: 77, height: 33)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .shadow(.inner(color: Color(hex: "EDEDED").opacity(0.25), radius: 7.5, x: 2, y: 9))
                        .shadow(.inner(color: Color(hex: "72930A"), radius: 5.7, x: 0, y: 4))
                        .shadow(.drop(color: Color(hex: "C5C5C5").opacity(0.57), radius: 11, x: 0, y: 4))
                    )
            )
            .overlay(
                Capsule()
                    .stroke(lineWidth: 1)
                    .foregroundStyle(.grayScale10)
            )
        }
        
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
