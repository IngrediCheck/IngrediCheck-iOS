import SwiftUI
import UIKit
import AuthenticationServices
import Supabase
import KeychainSwift
import GoogleSignIn
import GoogleSignInSwift
import CryptoKit
import PostHog

enum AuthControllerError: Error, LocalizedError {
    case rootViewControllerNotFound
    case signInResultIsNil
    case idTokenIsNil
    case unsupportedCredentialType

    var errorDescription: String? {
        switch self {
        case .rootViewControllerNotFound:
            return "Failed to locate root View Controller."
        case .signInResultIsNil:
            return "Google sign in result is nil."
        case .idTokenIsNil:
            return "Failed to get ID token from Google sign in result."
        case .unsupportedCredentialType:
            return "Received an unsupported authorization credential."
        }
    }
}

private final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding
{
    private var continuation: CheckedContinuation<OpenIDConnectCredentials, Error>?
    private let keychain: KeychainSwift

    var completionHandler: (() -> Void)?

    init(
        continuation: CheckedContinuation<OpenIDConnectCredentials, Error>,
        keychain: KeychainSwift
    ) {
        self.continuation = continuation
        self.keychain = keychain
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AuthControllerError.unsupportedCredentialType)
            continuation = nil
            completionHandler?()
            return
        }

        guard let identityTokenData = appleIDCredential.identityToken else {
            continuation?.resume(throwing: AuthControllerError.idTokenIsNil)
            continuation = nil
            completionHandler?()
            return
        }

        let identityTokenString = String(decoding: identityTokenData, as: UTF8.self)
        continuation?.resume(
            returning: OpenIDConnectCredentials(provider: .apple, idToken: identityTokenString)
        )
        continuation = nil
        completionHandler?()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
        completionHandler?()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let anchor = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            return anchor
        }

        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first {
            return window
        }

        return UIWindow()
    }
}

let supabaseClient =
    SupabaseClient(supabaseURL: Config.supabaseURL, supabaseKey: Config.supabaseKey)

enum SignInState {
    case signingIn
    case signedIn
    case signedOut
}

enum AccountUpgradeProvider {
    case apple
    case google
}

private enum AuthFlowMode {
    case signIn
    case link
}

//session?.user.identities[0].provider
@Observable final class AuthController {
    @MainActor var session: Session?
    @MainActor var signInState: SignInState = .signingIn
    @MainActor var isUpgradingAccount = false
    @MainActor var accountUpgradeError: Error?
    @MainActor var isInternalUser: Bool = false
    
    private let keychain = KeychainSwift()
    @MainActor private var appleSignInCoordinator: AppleSignInCoordinator?
    
    private static let anonUserNameKey = "anonEmail"
    private static let anonPasswordKey = "anonPassword"
    private static let deviceIdKey = "deviceId"
    private static let onboardingMetadataKey = "remoteOnboardingMetadata"
    private static var hasRegisteredDevice = false
    private static var hasPinged = false
    
    @MainActor init() {
        authChangeWatcher()
    }
    
    @MainActor
    var deviceId: String {
        if let storedDeviceId = keychain.get(AuthController.deviceIdKey) {
            return storedDeviceId
        } else {
            let newDeviceId = UUID().uuidString
            keychain.set(newDeviceId, forKey: AuthController.deviceIdKey)
            return newDeviceId
        }
    }
    
    @MainActor var signedInWithApple: Bool {
        guard let session = session else { return false }
        // Check identities first
        if let identities = session.user.identities {
            if identities.contains(where: { $0.provider.lowercased() == "apple" }) {
                return true
            }
        }
        // Fallback to appMetadata
        if let provider = session.user.appMetadata["provider"] as? String,
           provider.lowercased() == "apple" {
            return true
        }
        return false
    }
    
    @MainActor var signedInWithGoogle: Bool {
        guard let session = session else { return false }
        // Check identities first
        if let identities = session.user.identities {
            if identities.contains(where: { $0.provider.lowercased() == "google" }) {
                return true
            }
        }
        // Fallback to appMetadata
        if let provider = session.user.appMetadata["provider"] as? String,
           provider.lowercased() == "google" {
            return true
        }
        return false
    }
    
    @MainActor var signedInAsGuest: Bool {
        guard let session = session else { return false }
        
        // If we have an explicit anonymous identity
        if let identities = session.user.identities {
            if identities.contains(where: { $0.provider == "anonymous" }) {
                return true
            }
        }
        
        // If appMetadata says anonymous (or email for legacy guest)
        if let provider = session.user.appMetadata["provider"] as? String {
            if provider == "email" || provider == "anonymous" {
                return true
            }
        }
        
        // Specific flag on user object
        if session.user.isAnonymous == true {
            return true
        }
        
        // Fallback: check email pattern
        if let email = session.user.email {
            return email.hasPrefix("anon-") && email.hasSuffix("@example.com")
        }
        
        return false
    }
    
    @MainActor var currentUserEmail: String? {
        return session?.user.email
    }

    // Returns true if the email looks like Apple's private relay address
    @MainActor private func isAppleRelayEmail(_ email: String) -> Bool {
        let lowercased = email.lowercased()
        return lowercased.hasSuffix("@privaterelay.appleid.com") ||
               lowercased.contains(".privaterelay.appleid.com")
    }

    // Email to display in UI; hides Apple's private relay emails for better UX
    @MainActor var displayableEmail: String? {
        guard let email = session?.user.email, !email.isEmpty else { return nil }
        if signedInWithApple {
            // Hide Apple's private relay emails
            return isAppleRelayEmail(email) ? nil : email
        }
        return email
    }

    @MainActor var currentSignInProviderDisplay: (icon: String, text: String)? {
        if signedInWithGoogle {
            return ("g.circle", "Signed in with Google")
        }
        
        if signedInWithApple {
            return ("applelogo", "Signed in with Apple")
        }
        
        // Fallback for valid non-guest sessions where provider is missing
        if session != nil && !signedInAsGuest {
             return ("person.circle", "Signed in")
        }
        
        return nil
    }
    
    func authChangeWatcher() {
        Task {
            for await authStateChange in supabaseClient.auth.authStateChanges {
                await MainActor.run {
                    print("Auth change Event: \(authStateChange.event)")
                    self.handleSessionChange(
                        event: authStateChange.event,
                        session: authStateChange.session
                    )
                }
            }
        }
    }
    
    public func signOut() async {
        do {
            print("Signing Out")
            // Clear all onboarding resume state (local + remote) before sign-out.
            await clearAllOnboardingResumeStateRemoteAndLocal()
            _ = try await supabaseClient.auth.signOut()
        } catch AuthError.sessionMissing {
            print("Already signed out, nothing to revoke.")
        } catch let error as NSError {
            if error.domain == NSURLErrorDomain && error.code == -1009 {
                print("Internet connection appears to be offline.")
                return
            }
            print("Signout failed: \(error)")
        }
    }

    public func resetForAppReset() async {
        // Ensure we sign out of Supabase and clear all onboarding state.
        await signOut()
        // Also clear local onboarding caches even if there was no active session.
        await clearAllOnboardingResumeStateRemoteAndLocal()
        await MainActor.run {
            clearAnonymousCredentials()
            Self.hasRegisteredDevice = false
            Self.hasPinged = false
        }
    }

    func signIn() async {
        
        print("signIn()")

        guard await signInState != .signedIn else {
            print("Already Signed In, so not Signing in again")
            return
        }

        if let anonymousEmail = keychain.get(AuthController.anonUserNameKey),
           let anonymousPassword = keychain.get(AuthController.anonPasswordKey),
           await signInWithLegacyGuest(email: anonymousEmail, password: anonymousPassword) {
            return
        }

        await signInWithNewAnonymousAccount()
    }

    @MainActor
    public func upgradeCurrentAccount(to provider: AccountUpgradeProvider) async {
        guard signedInAsGuest else {
            print("Upgrade skipped: user is not signed in as guest.")
            return
        }

        guard isUpgradingAccount == false else {
            print("Upgrade already in progress.")
            return
        }

        isUpgradingAccount = true
        accountUpgradeError = nil

        do {
            let credentials: OpenIDConnectCredentials
            switch provider {
            case .apple:
                credentials = try await requestAppleIDToken()
            case .google:
                credentials = try await requestGoogleIDToken()
            }

            let session = try await finalizeAuth(with: credentials, mode: .link)
            self.session = session
            clearAnonymousCredentials()
            isUpgradingAccount = false
        } catch {
            isUpgradingAccount = false
            accountUpgradeError = error
            print("Account upgrade failed: \(error)")
        }
    }

    public func deleteAccount() async {
        // TODO: how to avoid creating new WebService object here?
        let webService = WebService()
        try? await webService.deleteUserAccount()
        await self.signOut()
        clearAnonymousCredentials()
    }
    
    private func signInWithLegacyGuest(email: String, password: String) async -> Bool {
        do {
            _ = try await supabaseClient.auth.signIn(email: email, password: password)
            return true
        } catch {
            print("Anonymous signin failed for stored credentials: \(error)")
            keychain.delete(AuthController.anonUserNameKey)
            keychain.delete(AuthController.anonPasswordKey)
            return false
        }
    }

    private func signInWithNewAnonymousAccount() async {
        do {
            _ = try await supabaseClient.auth.signInAnonymously()
        } catch {
            print("signInAnonymously failed: \(error)")
        }
    }
    
    public func handleSignInWithAppleCompletion(result: Result<ASAuthorization, Error>) {
        Task {
            do {
                let credentials = try Self.openIDCredentials(from: result, keychain: keychain)
                let session = try await finalizeAuth(with: credentials, mode: .signIn)
                await MainActor.run {
                    self.session = session
                }
            } catch {
                print("Apple sign-in failed: \(error)")
            }
        }
    }

    // Utility function to generate a random nonce
    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private static func openIDCredentials(
        from result: Result<ASAuthorization, Error>,
        keychain: KeychainSwift
    ) throws -> OpenIDConnectCredentials {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthControllerError.unsupportedCredentialType
            }

            guard let identityTokenData = appleIDCredential.identityToken else {
                throw AuthControllerError.idTokenIsNil
            }

            let identityTokenString = String(decoding: identityTokenData, as: UTF8.self)
            return OpenIDConnectCredentials(provider: .apple, idToken: identityTokenString)
        case .failure(let error):
            throw error
        }
    }

    @MainActor
    private func requestAppleIDToken() async throws -> OpenIDConnectCredentials {
        try await withCheckedThrowingContinuation { continuation in
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            let coordinator = AppleSignInCoordinator(
                continuation: continuation,
                keychain: keychain
            )
            coordinator.completionHandler = { [weak self] in
                self?.appleSignInCoordinator = nil
            }

            controller.delegate = coordinator
            controller.presentationContextProvider = coordinator

            appleSignInCoordinator = coordinator
            controller.performRequests()
        }
    }

    @MainActor
    private func requestGoogleIDToken() async throws -> OpenIDConnectCredentials {
        let nonce = randomNonceString()
        let rootController = try rootViewController()

        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: rootController,
                hint: nil,
                additionalScopes: [],
                nonce: nonce
            ) { signInResult, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result = signInResult else {
                    continuation.resume(throwing: AuthControllerError.signInResultIsNil)
                    return
                }

                guard let idToken = result.user.idToken else {
                    continuation.resume(throwing: AuthControllerError.idTokenIsNil)
                    return
                }

                let credentials = OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken.tokenString,
                    nonce: nonce
                )
                continuation.resume(returning: credentials)
            }
        }
    }

    private func finalizeAuth(
        with credentials: OpenIDConnectCredentials,
        mode: AuthFlowMode
    ) async throws -> Session {
        switch mode {
        case .signIn:
            return try await supabaseClient.auth.signInWithIdToken(credentials: credentials)
        case .link:
            return try await supabaseClient.auth.linkIdentityWithIdToken(credentials: credentials)
        }
    }

    @MainActor
    private func rootViewController() throws -> UIViewController {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene })
            .compactMap({ $0.keyWindow })
            .first?.rootViewController else {
                throw AuthControllerError.rootViewControllerNotFound
            }
        return rootViewController
    }

    private func clearAnonymousCredentials() {
        keychain.delete(AuthController.anonUserNameKey)
        keychain.delete(AuthController.anonPasswordKey)
        // Also clear any locally cached onboarding metadata
        UserDefaults.standard.removeObject(forKey: AuthController.onboardingMetadataKey)
    }

    public func signInWithGoogle(completion: ((Result<Void, Error>) -> Void)? = nil) {
        Task {
            do {
                let credentials = try await requestGoogleIDToken()
                let session = try await finalizeAuth(with: credentials, mode: .signIn)
                await MainActor.run {
                    self.session = session
                    completion?(.success(()))
                }
            } catch {
                print("Google sign-in failed: \(error)")
                await MainActor.run {
                    completion?(.failure(error))
                }
            }
        }
    }

    public func signInWithApple(completion: ((Result<Void, Error>) -> Void)? = nil) {
        Task {
            do {
                let credentials = try await requestAppleIDToken()
                let session = try await finalizeAuth(with: credentials, mode: .signIn)
                await MainActor.run {
                    self.session = session
                    completion?(.success(()))
                }
            } catch {
                print("Apple sign-in failed: \(error)")
                await MainActor.run {
                    completion?(.failure(error))
                }
            }
        }
    }
    
    @MainActor
    private func handleSessionChange(event: AuthChangeEvent, session: Session?) {
        self.session = session
        isUpgradingAccount = false
        
        if let session {
            signInState = .signedIn
            registerDeviceAfterLogin(session: session)
            pingAfterLogin()
            AnalyticsService.shared.refreshAnalyticsIdentity(session: session, isInternalUser: isInternalUser)
        } else {
            signInState = .signedOut
            let shouldReset = event == .signedOut || event == .userDeleted
            if shouldReset {
                AnalyticsService.shared.resetAnalytics()
                // Reset ping flag on sign out so it can run again on next login
                Self.hasPinged = false
            }
        }
    }
    
    
    @MainActor
    private func registerDeviceAfterLogin(session: Session) {
        guard !Self.hasRegisteredDevice else {
            return
        }
        Self.hasRegisteredDevice = true
        
        WebService().registerDeviceAfterLogin(deviceId: deviceId) { [weak self] isInternal in
            guard let self = self, let isInternal = isInternal else { return }
            
            Task { @MainActor in
                if isInternal != self.isInternalUser {
                    self.isInternalUser = isInternal
                    AnalyticsService.shared.refreshAnalyticsIdentity(session: session, isInternalUser: isInternal)
                }
            }
        }
    }
    
    @MainActor
    private func pingAfterLogin() {
        guard !Self.hasPinged else {
            return
        }
        Self.hasPinged = true
        
        // Fire-and-forget ping call
        WebService().ping()
    }
    
    @MainActor
    func setInternalUser(_ value: Bool) {
        guard value != isInternalUser else { return }
        isInternalUser = value
        if let session = session {
            AnalyticsService.shared.refreshAnalyticsIdentity(session: session, isInternalUser: value)
        }
    }
    
    // MARK: - Remote Onboarding Metadata Sync
    
    /// Syncs current onboarding state to Supabase raw_user_meta_data
    /// Call this whenever navigation changes during onboarding
    @MainActor
    func syncRemoteOnboardingMetadata(from coordinator: AppNavigationCoordinator) async {
        do {
            let metadata = coordinator.buildOnboardingMetadata()
            print("[OnboardingMeta] syncRemote: canvasRoute=\(coordinator.currentCanvasRoute), bottomSheetRoute=\(coordinator.currentBottomSheetRoute), flowType=\(metadata.flowType?.rawValue ?? "nil"), stage=\(metadata.stage?.rawValue ?? "nil"), stepId=\(metadata.currentStepId ?? "nil"), bottomSheetId=\(metadata.bottomSheetRoute?.rawValue ?? "nil"), bottomSheetParam=\(metadata.bottomSheetRouteParam ?? "nil")")
            
            // Always cache locally so we can restore even before login.
            Self.cacheOnboardingMetadataLocally(metadata)
            
            // If there's no Supabase session yet (pre-login), stop here.
            guard session != nil else {
                print("[OnboardingMeta] syncRemote: no active session, cached locally only")
                return
            }
            
            guard let anyJSONDict = Self.encodeMetadataToAnyJSON(metadata) else {
                print("❌ Failed to encode onboarding metadata")
                return
            }
            // This maps directly to raw_user_meta_data in auth.users
            let attrs = UserAttributes(data: anyJSONDict)
            let updatedUser = try await supabaseClient.auth.update(user: attrs)
            // Keep local session in sync
            self.session?.user = updatedUser
            print("✅ Synced onboarding metadata to Supabase: stage=\(metadata.stage?.rawValue ?? "nil"), stepId=\(metadata.currentStepId ?? "nil"), bottomSheet=\(metadata.bottomSheetRoute?.rawValue ?? "nil")")
        } catch {
            print("❌ Failed to sync onboarding metadata: \(error)")
        }
    }
    
    /// Helper to encode RemoteOnboardingMetadata into [String: AnyJSON] for Supabase
    private static func encodeMetadataToAnyJSON(_ metadata: RemoteOnboardingMetadata) -> [String: AnyJSON]? {
        guard let jsonData = try? JSONEncoder().encode(metadata),
              let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        
        var anyJSONDict: [String: AnyJSON] = [:]
        for (key, value) in jsonDict {
            if let stringValue = value as? String {
                if let encoded = try? AnyJSON(stringValue) {
                    anyJSONDict[key] = encoded
                }
            } else if let boolValue = value as? Bool {
                if let encoded = try? AnyJSON(boolValue) {
                    anyJSONDict[key] = encoded
                }
            }
            // We intentionally skip NSNull / nil values so they are not sent.
        }
        return anyJSONDict
    }
    
    /// Cache onboarding metadata locally so we can restore pre-login state.
    private static func cacheOnboardingMetadataLocally(_ metadata: RemoteOnboardingMetadata) {
        if let data = try? JSONEncoder().encode(metadata) {
            UserDefaults.standard.set(data, forKey: onboardingMetadataKey)
        }
    }
    
    /// Read cached onboarding metadata from UserDefaults.
    private static func readLocalOnboardingMetadata() -> RemoteOnboardingMetadata? {
        guard let data = UserDefaults.standard.data(forKey: onboardingMetadataKey) else {
            return nil
        }
        return try? JSONDecoder().decode(RemoteOnboardingMetadata.self, from: data)
    }
    
    // MARK: - Global Onboarding Reset Helpers
    
    /// Clears all local and remote onboarding-resume related state.
    @MainActor
    private func clearAllOnboardingResumeStateRemoteAndLocal() async {
        // 1) Clear local Supabase-metadata cache
        UserDefaults.standard.removeObject(forKey: AuthController.onboardingMetadataKey)
        // 2) Clear local canvas/bottom-sheet resume snapshot
        OnboardingResumeStore.clear()
        
        // 3) Clear remote raw_user_meta_data if we have a session
        guard session != nil else {
            print("[OnboardingMeta] clearAll: no session, skipped remote clear")
            return
        }
        
        let clearMetadata = RemoteOnboardingMetadata(
            flowType: nil,
            stage: .none,
            currentStepId: nil,
            bottomSheetRoute: nil,
            bottomSheetRouteParam: nil
        )
        
        if let anyJSONDict = Self.encodeMetadataToAnyJSON(clearMetadata) {
            let attrs = UserAttributes(data: anyJSONDict)
            do {
                try await supabaseClient.auth.update(user: attrs)
                print("[OnboardingMeta] clearAll: remote raw_user_meta_data cleared")
            } catch {
                print("[OnboardingMeta] clearAll: failed to clear remote metadata: \(error)")
            }
        }
    }
    
    /// Reads onboarding metadata from Supabase and returns it for restoration.
    ///
    /// We avoid JSONSerialization here because `userMetadata` may contain
    /// SDK-specific wrapper types that are not JSON-serializable (leading to
    /// `Invalid type in JSON write (__SwiftValue)` crashes). Instead we
    /// manually pull out just the string fields we care about.
    @MainActor
    func readRemoteOnboardingMetadata() -> RemoteOnboardingMetadata? {
        // 1) Prefer Supabase user metadata if available
        if let rawMetadata = session?.user.userMetadata,
           let dict = rawMetadata as? [String: Any] {
            
            let flowTypeRaw = dict["flowType"] as? String
            let stageRaw = dict["stage"] as? String
            let stepId = dict["currentStepId"] as? String
            let bottomRouteRaw = dict["bottomSheetRoute"] as? String
            let bottomRouteParam = dict["bottomSheetRouteParam"] as? String
            
            if flowTypeRaw != nil || stageRaw != nil || stepId != nil || bottomRouteRaw != nil {
                let flowType = flowTypeRaw.flatMap { OnboardingFlowType(rawValue: $0) }
                let stage = stageRaw.flatMap { RemoteOnboardingStage(rawValue: $0) }
                let bottomRouteId = bottomRouteRaw.flatMap { BottomSheetRouteIdentifier(rawValue: $0) }
                
                let metadata = RemoteOnboardingMetadata(
                    flowType: flowType,
                    stage: stage,
                    currentStepId: stepId,
                    bottomSheetRoute: bottomRouteId,
                    bottomSheetRouteParam: bottomRouteParam
                )
                
                print("[OnboardingMeta] readRemote: using Supabase metadata: flowType=\(metadata.flowType?.rawValue ?? "nil"), stage=\(metadata.stage?.rawValue ?? "nil"), stepId=\(metadata.currentStepId ?? "nil"), bottomSheetId=\(metadata.bottomSheetRoute?.rawValue ?? "nil"), bottomSheetParam=\(metadata.bottomSheetRouteParam ?? "nil")")
                return metadata
            }
        }
        
        // 2) Fallback to local cache (covers pre-login kills)
        if let cached = Self.readLocalOnboardingMetadata() {
            print("[OnboardingMeta] readRemote: using locally cached metadata: flowType=\(cached.flowType?.rawValue ?? "nil"), stage=\(cached.stage?.rawValue ?? "nil"), stepId=\(cached.currentStepId ?? "nil"), bottomSheetId=\(cached.bottomSheetRoute?.rawValue ?? "nil"), bottomSheetParam=\(cached.bottomSheetRouteParam ?? "nil")")
            return cached
        }
        
        print("[OnboardingMeta] readRemote: no metadata found (Supabase or local)")
        return nil
    }
    
    /// Restores navigation state from Supabase metadata
    /// Call this on app launch after session is available
    @MainActor
    func restoreOnboardingPosition(into coordinator: AppNavigationCoordinator) {
        guard let metadata = readRemoteOnboardingMetadata(),
              let stage = metadata.stage,
              let flowType = metadata.flowType else {
            print("No onboarding metadata to restore")
            return
        }
        
        print("🔄 Restoring onboarding: stage=\(stage.rawValue), flowType=\(flowType.rawValue), stepId=\(metadata.currentStepId ?? "nil"), bottomSheet=\(metadata.bottomSheetRoute?.rawValue ?? "nil")")
        
        // Restore canvas route based on stage
        switch stage {
        case .none, .completed:
            coordinator.showCanvas(.home)
            
        case .preOnboarding:
            coordinator.showCanvas(.heyThere)
            
        case .choosingFlow:
            coordinator.showCanvas(.letsMeetYourIngrediFam)
            
        case .dietaryIntro:
            let isFamilyFlow = flowType != .individual
            coordinator.showCanvas(.dietaryPreferencesAndRestrictions(isFamilyFlow: isFamilyFlow))
            
        case .dynamicOnboarding:
            coordinator.showCanvas(.mainCanvas(flow: flowType))
            
        case .fineTune:
            coordinator.showCanvas(.mainCanvas(flow: flowType))
        }
        
        // Restore bottom sheet route if available
        if let routeId = metadata.bottomSheetRoute {
            let restoredRoute = AppNavigationCoordinator.restoreBottomSheetRoute(
                from: routeId,
                param: metadata.bottomSheetRouteParam
            )
            print("[OnboardingMeta] restore: applying bottomSheetRoute=\(routeId.rawValue) with param=\(metadata.bottomSheetRouteParam ?? "nil")")
            coordinator.navigateInBottomSheet(restoredRoute)
        } else if let stepId = metadata.currentStepId, stage == .dynamicOnboarding {
            // Fallback: use stepId if bottomSheetRoute wasn't stored (backward compatibility)
            print("[OnboardingMeta] restore: fallback to onboardingStep with stepId=\(stepId)")
            coordinator.navigateInBottomSheet(.onboardingStep(stepId: stepId))
        } else if stage == .fineTune {
            // Fallback for fineTune stage
            print("[OnboardingMeta] restore: fallback to fineTuneYourExperience bottom sheet")
            coordinator.navigateInBottomSheet(.fineTuneYourExperience)
        }
    }
}
