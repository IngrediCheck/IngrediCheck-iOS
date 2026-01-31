import Foundation
import PostHog
import Supabase

final class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    func configure() {
        Task.detached {
            let POSTHOG_API_KEY = "phc_BFYelq2GeyigXBP3MgML57wKoWfLe5MW7m6HMYhtX8m"
            let POSTHOG_HOST = "https://us.i.posthog.com"

            let config = PostHogConfig(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
            
            // some required permission for config - Ref KIN Cal App
            config.captureApplicationLifecycleEvents = true
            
            config.sessionReplay = true
            
            config.sessionReplayConfig.maskAllTextInputs = false
            
            config.sessionReplayConfig.maskAllImages = false
            
            config.sessionReplayConfig.maskAllSandboxedViews = true
            
            config.sessionReplayConfig.captureNetworkTelemetry = true
            
            config.sessionReplayConfig.screenshotMode = true
            
            config.sessionReplayConfig.throttleDelay = 1.0
            
            PostHogSDK.shared.setup(config)
        }
    }
    
    func resetAnalytics() {
        Task.detached {
            PostHogSDK.shared.reset()
        }
    }
    
    func trackOnboarding(_ event: String, properties: [String: Any] = [:]) {
        Task.detached {
            PostHogSDK.shared.capture(event, properties: properties)
        }
    }

    func refreshAnalyticsIdentity(session: Session, isInternalUser: Bool, authProvider: String) {
        Task.detached {
            var properties: [String: Any] = [:]

            // Only add is_internal when it's true (from API responses)
            if isInternalUser {
                properties["is_internal"] = true
            }

            if let email = session.user.email {
                properties["email"] = email
            }

            properties["auth_provider"] = authProvider

            let distinctId = session.user.id.uuidString
            PostHogSDK.shared.identify(distinctId, userProperties: properties)
        }
    }
}

