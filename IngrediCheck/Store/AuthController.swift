import SwiftUI
import AuthenticationServices
import Supabase
import KeychainSwift
import GoogleSignIn
import GoogleSignInSwift
import CryptoKit

enum AuthControllerError: Error, LocalizedError {
    case rootViewControllerNotFound
    case signInResultIsNil
    case idTokenIsNil

    var errorDescription: String? {
        switch self {
        case .rootViewControllerNotFound:
            return "Failed to locate root View Controller."
        case .signInResultIsNil:
            return "Google sign in result is nil."
        case .idTokenIsNil:
            return "Failed to get ID token from Google sign in result."
        }
    }
}

let supabaseClient =
    SupabaseClient(supabaseURL: Config.supabaseURL, supabaseKey: Config.supabaseKey)

enum SignInState {
    case signingIn
    case signedIn
    case signedOut
}

//session?.user.identities[0].provider
@Observable final class AuthController {
    @MainActor var session: Session?
    @MainActor var signInState: SignInState = .signingIn
    
    private let keychain = KeychainSwift()
    
    private static let anonUserNameKey = "anonEmail"
    private static let anonPasswordKey = "anonPassword"
    
    init() {
        authChangeWatcher()
    }
    
    @MainActor var signedInWithApple: Bool {
        if let provider = self.session?.user.appMetadata["provider"] {
            return provider == "apple"
        }
        return false
    }
    
    @MainActor var signedInAsGuest: Bool {
        if let provider = self.session?.user.appMetadata["provider"] as? String {
            return provider == "email" || provider == "anonymous"
        }
        
        if self.session?.user.isAnonymous == true {
            return true
        }
        
        if let email = self.session?.user.email {
            return email.hasPrefix("anon-") && email.hasSuffix("@example.com")
        }
        
        return false
    }
    
    @MainActor var signedInWithGoogle: Bool {
        if let provider = self.session?.user.appMetadata["provider"] {
            return provider == "google"
        }
        return false
    }
    
    func authChangeWatcher() {
        Task {
            for await authStateChange in supabaseClient.auth.authStateChanges {
                await MainActor.run {
                    print("Auth change Event: \(authStateChange.event)")
                    self.session = authStateChange.session
                    if authStateChange.session == nil {
                        signInState = .signedOut
                    } else {
                        signInState = .signedIn
                    }
                }
            }
        }
    }
    
    public func signOut() async {
        do {
            print("Signing Out")
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

    public func deleteAccount() async {
        // TODO: how to avoid creating new WebService object here?
        let webService = WebService()
        try? await webService.deleteUserAccount()
        await self.signOut()
        keychain.delete(AuthController.anonUserNameKey)
        keychain.delete(AuthController.anonPasswordKey)
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
        print("handleSignInWithAppleCompletion: \(result)")
        switch result {
            case .success(let authorization):
                let appleIDCredential = authorization.credential as! ASAuthorizationAppleIDCredential
            
                if let currentUserName = appleIDCredential.fullName?.formatted(), !currentUserName.isEmpty {
                    print("Setting currentUserName to \(currentUserName)")
                    keychain.set(currentUserName, forKey: "currentUserName")
                }

                guard let identityTokenData = appleIDCredential.identityToken else {
                    print("Error: identityToken is nil")
                    return
                }

                let identityTokenString = String(decoding: identityTokenData, as: UTF8.self)
                
                Task {
                    do {
                        let credentials = OpenIDConnectCredentials(provider: .apple, idToken: identityTokenString)
                        let session = try await supabaseClient.auth.signInWithIdToken(credentials: credentials)
                        print("signInWithIdToken Success")
                        await MainActor.run {
                            self.session = session
                        }
                    } catch {
                        print ("signInWithIdToken failed: \(error)")
                    }
                }

            case .failure(let error):
                print(error.localizedDescription)
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

    public func signInWithGoogle(completion: ((Result<Void, Error>) -> Void)? = nil) {
        let nonce = randomNonceString()
        guard let rootViewController = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene })
            .compactMap({ $0.keyWindow })
            .first?.rootViewController else {
                print("Failed to locate root View Controller")
                completion?(.failure(AuthControllerError.rootViewControllerNotFound))
                return
            }

        GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController,
            hint: nil,
            additionalScopes: [],
            nonce: nonce, // Pass the nonce here
            completion: { signInResult, error in
                if let error = error {
                    print("Error signing in with Google: \(error)")
                    completion?(.failure(error))
                    return
                }

                guard let result = signInResult else {
                    print("Google sign in result is nil")
                    completion?(.failure(AuthControllerError.signInResultIsNil))
                    return
                }

                if let idToken = result.user.idToken {
                    Task {
                        do {
                            let credentials = OpenIDConnectCredentials(
                                provider: .google,
                                idToken: idToken.tokenString,
                                nonce: nonce // Pass the same nonce to Supabase
                            )
                            let session = try await supabaseClient.auth.signInWithIdToken(credentials: credentials)
                            print("Google sign in successful: \(session)")
                            await MainActor.run {
                                self.session = session
                                completion?(.success(()))
                            }
                        } catch {
                            print("Supabase sign-in error: \(error)")
                            completion?(.failure(error))
                        }
                    }
                } else {
                    print("Failed to get ID token")
                    completion?(.failure(AuthControllerError.idTokenIsNil))
                }
            }
        )
    }
}
