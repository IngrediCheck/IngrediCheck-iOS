import SwiftUI
import AuthenticationServices
import Supabase
import KeychainSwift
import Network

let supabaseClient =
    SupabaseClient(supabaseURL: Config.supabaseURL, supabaseKey: Config.supabaseKey)

@Observable final class AuthController {
    @MainActor var session: Session?
    @MainActor var authEvent: AuthChangeEvent?
    
    private let keychain = KeychainSwift()
    private var monitor: NWPathMonitor?
    
    init() {
        newtworkWatcher()
        authChangeWatcher()
    }

    private func newtworkWatcher() {
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { path in
            print("NetworkMonitor: \(path)")
            if path.status == .satisfied {
                Task { await self.signIn() }
            } else {
                Task { await self.signOut() }
            }
        }
        monitor?.start(queue: DispatchQueue.global())
    }

    func authChangeWatcher() {
        Task {
            for await authStateChange in supabaseClient.auth.authStateChanges {
                print("Auth change Event: \(authStateChange.event)")
                await MainActor.run {
                    self.authEvent = authStateChange.event
                    self.session = authStateChange.session
                }
            }
        }
    }
    
    private func signOut() async {
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
    
    private func signIn() async {
        
        guard await authEvent != .signedIn else {
            print("Already Signed In, so not Signing in again")
            return
        }

        if let anonymousEmail = keychain.get("anonEmail"), let anonymousPassword = keychain.get("anonPassword") {

            print("Signing in with anonEmail")
            do {
                _ = try await supabaseClient.auth.signIn(email: anonymousEmail, password: anonymousPassword)
            } catch let error as NSError {
                if error.domain == NSURLErrorDomain && error.code == -1009 {
                    print("Internet connection appears to be offline.")
                    return
                }
                print("Anonymous signin failed: \(error)")
            }
        } else {
            
            print("Signing up with signInAnonymously")
            do {
                let _ = try await supabaseClient.auth.signInAnonymously()
            } catch let error as NSError {
                if error.domain == NSURLErrorDomain && error.code == -1009 {
                    print("Internet connection appears to be offline.")
                    return
                }
                print("supabaseClient.auth.signInAnonymously() failed: \(error)")
            }
        }
    }
}
