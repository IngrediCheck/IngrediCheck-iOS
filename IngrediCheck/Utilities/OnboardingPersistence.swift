//
//  OnboardingPersistence.swift
//  IngrediCheck
//
//  Created by Vishal Paliwal on 09/01/26.
//

import Foundation
import Supabase
import os

// MARK: - Centralized Logging Utility

/// Centralized logging utility using Apple's unified logging (os_log).
/// Logs appear in Console.app, idevicesyslog, and Xcode debugger.
///
/// Usage:
///   Log.debug("FamilyStore", "Loading family data...")
///   Log.error("WebService", "❌ Failed to fetch: \(error)")
struct Log {
    /// Uses NSLog for idevicesyslog compatibility (os_log doesn't appear in idevicesyslog)
    static func debug(_ category: String, _ message: String) {
        NSLog("[%@] %@", category, message)
    }

    static func info(_ category: String, _ message: String) {
        NSLog("[%@] %@", category, message)
    }

    static func warning(_ category: String, _ message: String) {
        NSLog("[%@] ⚠️ %@", category, message)
    }

    static func error(_ category: String, _ message: String) {
        NSLog("[%@] ❌ %@", category, message)
    }
}

/// A helper class to manage the onboarding state (Stage-based) both locally and remotely.
/// It prioritizes local UserDefaults for immediate synchronous access during app launch,
/// but also handles syncing that state to Supabase.
@MainActor
final class OnboardingPersistence {
    static let shared = OnboardingPersistence()
    
    // MARK: - Local Persistence
    private let stageKey = "onboarding_local_stage"
    
    /// Access the global SupabaseClient defined in AuthController.swift
    private var client: SupabaseClient {
        return supabaseClient
    }
    
    /// The current onboarding stage, backed by UserDefaults.
    /// Defaults to .none (start over) if nothing is saved.
    var localStage: RemoteOnboardingStage {
        get {
            guard let raw = UserDefaults.standard.string(forKey: stageKey),
                  let stage = RemoteOnboardingStage(rawValue: raw) else {
                return .none
            }
            return stage
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: stageKey)
        }
    }
    
    /// Checks if onboarding is locally marked as completed.
    /// This is the fast path for app launch.
    var isLocallyCompleted: Bool {
        return localStage == .completed
    }
    
    // MARK: - State Management
    
    /// Sets the stage locally AND triggers a remote sync.
    /// Use this instead of modifying `localStage` directly when application logic changes the stage.
    func setStage(_ stage: RemoteOnboardingStage, coordinator: AppNavigationCoordinator? = nil) {
        Log.debug("OnboardingPersistence", "Setting local stage to: \(stage.rawValue)")
        localStage = stage
        
        // Trigger remote sync
        Task {
            await syncRemote(stage: stage, coordinator: coordinator)
        }
    }
    
    /// Marks the onboarding as completed locally and synced remotely.
    /// Call this at the definitive end of any onboarding flow (e.g. Success sheet, Login).
    func markCompleted() {
        Log.debug("OnboardingPersistence", "Marking onboarding as completed.")
        setStage(.completed)
    }
    
    /// Syncs the current state from the coordinator to both local storage and remote Supabase.
    /// Call this whenever navigation changes.
    func sync(from coordinator: AppNavigationCoordinator) async {
        // Crucial: Only sync if we have a valid session (Guest or User).
        // This prevents persisting "Get Started" state for new users who haven't performed Guest Login yet.
        guard let _ = try? await client.auth.session else {
             Log.debug("OnboardingPersistence", "sync skipped: No active session.")
             return
        }

        // CRITICAL: If onboarding is already completed locally, don't overwrite it.
        // This prevents regression when navigation temporarily goes to early onboarding screens.
        if isLocallyCompleted {
            Log.debug("OnboardingPersistence", "sync skipped: Onboarding already completed locally. Preventing regression.")
            return
        }

        let metadata = coordinator.buildOnboardingMetadata()
        if let stage = metadata.stage {
            // Update local stage to match what the coordinator thinks we are in
            // This ensures we don't drift if the coordinator changes state logic
            Log.debug("OnboardingPersistence", "sync: Updating local stage to match coordinator: \(stage.rawValue)")
            localStage = stage
            await syncRemote(stage: stage, coordinator: coordinator)
        }
    }
    
    /// Resets the local completion flag (e.g. for Logout).
    func reset() {
        Log.debug("OnboardingPersistence", "Resetting local onboarding state.")
        UserDefaults.standard.removeObject(forKey: stageKey)
    }
    
    // MARK: - Remote Sync
    
    /// Syncs the specific stage (and detailed metadata if coordinator is provided) to Supabase.
    private func syncRemote(stage: RemoteOnboardingStage, coordinator: AppNavigationCoordinator?) async {
        guard let session = try? await client.auth.session else {
             Log.debug("OnboardingPersistence", "Remote sync skipped: no active session.")
             return
        }
        
        // Build metadata. If coordinator is missing, we at least save the stage.
        var metadata: RemoteOnboardingMetadata
        if let coordinator = coordinator {
             metadata = coordinator.buildOnboardingMetadata()
             // Force override stage with what was passed, to ensure consistency
             metadata.stage = stage
        } else {
             // Minimal metadata just to save stage
             metadata = RemoteOnboardingMetadata(flowType: nil, stage: stage, currentStepId: nil, bottomSheetRoute: nil, bottomSheetRouteParam: nil)
        }
        
        // Encode and Update
        do {
            if let anyJSONDict = encodeMetadataToAnyJSON(metadata) {
                // UserAttributes requires [String: AnyJSON]
                let attrs = UserAttributes(data: anyJSONDict)
                try await client.auth.update(user: attrs)
                Log.debug("OnboardingPersistence", "✅ [OnboardingPersistence] Synced remote stage: \(stage.rawValue)")
            }
        } catch {
            Log.error("OnboardingPersistence", "❌ [OnboardingPersistence] Failed to sync remote stage: \(error)")
        }
    }
    
    /// Reads remote metadata and updates local state if remote is "ahead" (e.g. completed).
    /// Returns the fetched metadata for specific navigation restoration.
    func restore(into coordinator: AppNavigationCoordinator) async {
        // 1. Fetch Remote Metadata
        guard let metadata = await fetchRemoteMetadata() else {
            Log.debug("OnboardingPersistence", "No remote metadata found.")
            // Falling back to whatever local state we have or default
            return
        }
        
        guard let remoteStage = metadata.stage else { return }
        Log.debug("OnboardingPersistence", "Remote stage is: \(remoteStage.rawValue)")
        
        // 2. Conflict Resolution
        // If remote says completed, update local immediately.
        if remoteStage == .completed {
            if localStage != .completed {
                Log.debug("OnboardingPersistence", "Remote is completed but local wasn't. Updating local -> completed.")
                localStage = .completed
            }
            coordinator.showCanvas(.home)
            return
        }
        
        // If local says completed, TRUST LOCAL (prevent regression).
        if isLocallyCompleted {
             Log.debug("OnboardingPersistence", "Local is completed. Ignoring non-completed remote state.")
             coordinator.showCanvas(.home)
             return
        }
        
        // 3. Apply Detailed Restoration
        // If neither is completed, we restore the specific state from metadata
        await applyRestoration(metadata: metadata, into: coordinator)
    }
    
    func fetchRemoteMetadata() async -> RemoteOnboardingMetadata? {
        // Fetch fresh user object from server to ensure metadata is up-to-date
        guard let user = try? await client.auth.user() else {
            Log.debug("OnboardingPersistence", "fetchRemoteMetadata: Failed to fetch user.")
            return nil
        }
        
        let userUserMeta = user.userMetadata
        
        // Extract fields using keys that match RemoteOnboardingMetadata properties
        let flowTypeRaw = extractString(from: userUserMeta["flowType"])
        let stageRaw = extractString(from: userUserMeta["stage"])
        let stepId = extractString(from: userUserMeta["currentStepId"])
        let bottomRouteRaw = extractString(from: userUserMeta["bottomSheetRoute"])
        let bottomRouteParam = extractString(from: userUserMeta["bottomSheetRouteParam"])
        
        guard flowTypeRaw != nil || stageRaw != nil || stepId != nil || bottomRouteRaw != nil else {
            return nil
        }
        
        return RemoteOnboardingMetadata(
            flowType: flowTypeRaw.flatMap { OnboardingFlowType(rawValue: $0) },
            stage: stageRaw.flatMap { RemoteOnboardingStage(rawValue: $0) },
            currentStepId: stepId,
            bottomSheetRoute: bottomRouteRaw.flatMap { BottomSheetRouteIdentifier(rawValue: $0) },
            bottomSheetRouteParam: bottomRouteParam
        )
    }
    
    /// Applies metadata to coordinator to visually restore state
    private func applyRestoration(metadata: RemoteOnboardingMetadata, into coordinator: AppNavigationCoordinator) async {
        let (canvas, sheet) = AppNavigationCoordinator.restoreState(from: metadata)
        
        await MainActor.run {
            coordinator.showCanvas(canvas)
            coordinator.navigateInBottomSheet(sheet)
        }
    }

    // MARK: - Private Helpers
    
    /// Encodes metadata to [String: AnyJSON]
    private func encodeMetadataToAnyJSON(_ metadata: RemoteOnboardingMetadata) -> [String: AnyJSON]? {
        guard let data = try? JSONEncoder().encode(metadata),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        var result = [String: AnyJSON]()
        for (key, value) in jsonObject {
            result[key] = toAnyJSON(value)
        }
        return result
    }
    
    /// Recursively converts Any -> AnyJSON
    private func toAnyJSON(_ value: Any) -> AnyJSON {
        if let s = value as? String { return .string(s) }
        if let i = value as? Int { return .integer(i) }
        if let d = value as? Double { return .double(d) }
        if let b = value as? Bool { return .bool(b) }
        if let a = value as? [Any] { return .array(a.map { toAnyJSON($0) }) }
        if let d = value as? [String: Any] {
            var dict = [String: AnyJSON]()
            d.forEach { dict[$0] = toAnyJSON($1) }
            return .object(dict)
        }
        return .null
    }

    /// Safely extracts String from AnyJSON
    private func extractString(from json: AnyJSON?) -> String? {
        guard let json = json else { return nil }
        
        switch json {
        case .string(let s):
            return s
        case .null:
            return nil
        default:
            // Fallback for primitive types
            if case .integer(let i) = json { return String(i) }
            if case .double(let d) = json { return String(d) }
            if case .bool(let b) = json { return String(b) }
            return nil
        }
    }
}
