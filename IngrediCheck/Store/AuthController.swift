import SwiftUI
import AuthenticationServices
import Supabase
import KeychainSwift

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
        if let provider = self.session?.user.appMetadata["provider"] {
            return provider == "email"
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
           let anonymousPassword = keychain.get(AuthController.anonPasswordKey) {
            do {
                _ = try await supabaseClient.auth.signIn(email: anonymousEmail, password: anonymousPassword)
            } catch {
                print("Anonymous signin failed: \(error)")
                return
            }
        } else {
            print("Signing up with new anonymous email and password.")
            
            let anonymousEmail = "anon-\(UUID().uuidString)@example.com"
            let anonymousPassword = UUID().uuidString
            
            do {
                _ = try await supabaseClient.auth.signUp(email: anonymousEmail, password: anonymousPassword)
                _ = try await supabaseClient.auth.signIn(email: anonymousEmail, password: anonymousPassword)
                keychain.set(anonymousEmail, forKey: AuthController.anonUserNameKey)
                keychain.set(anonymousPassword, forKey: AuthController.anonPasswordKey)
            } catch {
                print("Anonymous Signup failed: \(error)")
                return
            }
        }
    }

    public func deleteAccount() async {
        // TODO: how to avoid creating new WebService object here?
        let webService = WebService()
        try? await webService.deleteUserAccount()
        await self.signOut()
        keychain.delete(AuthController.anonUserNameKey)
        keychain.delete(AuthController.anonPasswordKey)
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
}
