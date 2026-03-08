import Foundation
import PostHog
import Supabase

final class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}

    private var isEnabled: Bool {
        !AppRuntimePolicy.disablesAnalytics
    }
    
    func configure() {
        guard isEnabled else { return }
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
        guard isEnabled else { return }
        Task.detached {
            PostHogSDK.shared.reset()
        }
    }

    func capture(_ event: String, properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        Task.detached {
            PostHogSDK.shared.capture(event, properties: properties)
        }
    }

    func trackOnboarding(_ event: String, properties: [String: Any] = [:]) {
        capture(event, properties: properties)
    }

    func captureAPIError(
        endpoint: String,
        errorType: String,
        statusCode: Int? = nil,
        error: String? = nil
    ) {
        var properties: [String: Any] = [
            "endpoint": endpoint,
            "error_type": errorType
        ]
        if let statusCode { properties["status_code"] = statusCode }
        if let error { properties["error"] = error }
        capture("API Error", properties: properties)
    }

    func refreshAnalyticsIdentity(session: Session, isInternalUser: Bool, authProvider: String) {
        guard isEnabled else { return }
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
