import Foundation
struct Config {
    static let supabaseURL = URL(string: "https://wqidjkpfdrvomfkmefqc.supabase.co")!
    static let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndxaWRqa3BmZHJ2b21ma21lZnFjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDczNDgxODksImV4cCI6MjAyMjkyNDE4OX0.sgRV4rLB79VxYx5a_lkGAlB2VcQRV2beDEK3dGH4_nI"
    static let supabaseFunctionsURLBase = "https://wqidjkpfdrvomfkmefqc.supabase.co/functions/v1/ingredicheck/"
    
    // MARK: - App Flow Configuration
    /// Set to true to enable preview/testing flow with slide-based splash screen
    /// Set to false for production flow with standard splash screen
    static let usePreviewFlow: Bool = {
        #if DEBUG
        return true // Change to true to test preview flow
        #else
        return false // Always false in production
        #endif
    }()
}
