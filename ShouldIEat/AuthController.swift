import SwiftUI
import AuthenticationServices
import Supabase
import KeychainSwift

enum Config {
    static let supabaseURL =
        URL(string: "https://bsihbsyxvfwdjqnyxaoe.supabase.co")!
    static let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzaWhic3l4dmZ3ZGpxbnl4YW9lIiwicm9sZSI6ImFub24iLCJpYXQiOjE2ODcwMDkxODEsImV4cCI6MjAwMjU4NTE4MX0.pV1ArWUMNc4JVHgel8xFggDnlfSGCov97OEq57RbKUk"
}
    
let supabaseClient =
    SupabaseClient(supabaseURL: Config.supabaseURL, supabaseKey: Config.supabaseKey)

@Observable final class AuthController {
    var session: Session?
    var authEvent: AuthChangeEvent?
    let keychain = KeychainSwift()
    
    func initialize() {
        Task {
            await createOrRetrieveAnonymousUser()
            for await authStateChange in await supabaseClient.auth.authStateChanges {
                print("Auth change Event: \(authStateChange.event)")
                self.authEvent = authStateChange.event
                self.session = authStateChange.session
            }
        }
    }
    
    private func createOrRetrieveAnonymousUser() async {
        if let anonymousEmail = keychain.get("anonEmail"), let anonymousPassword = keychain.get("anonPassword") {
            do {
                _ = try await supabaseClient.auth.signIn(email: anonymousEmail, password: anonymousPassword)
                return
            } catch {
                print("Anonymous signin failed: \(error)")
            }
        }
        print("Signing up with new anonymous email and password.")

        let anonymousEmail = "anon-\(UUID().uuidString)@example.com"
        let anonymousPassword = UUID().uuidString

        do {
            _ = try await supabaseClient.auth.signUp(email: anonymousEmail, password: anonymousPassword)
            _ = try await supabaseClient.auth.signIn(email: anonymousEmail, password: anonymousPassword)
            keychain.set(anonymousEmail, forKey: "anonEmail")
            keychain.set(anonymousPassword, forKey: "anonPassword")
        } catch {
            print("Anonymous Signup failed: \(error)")
        }
    }
}
