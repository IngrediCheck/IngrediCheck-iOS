# Anonymous Guest Upgrade Design

## Context
- Anonymous sign-in (`signInAnonymously`) is the default entry path and stores Supabase credentials in `AuthController` along with a keychain copy of the email/password for legacy guests.
- Users currently have no path to attach a permanent identity without wiping the anonymous account and starting from scratch.
- `AuthController` already supports Apple and Google login for brand-new sessions via `signInWithIdToken`, and the settings sheet exposes only sign-out and delete actions.

## Goals
- Let an anonymous guest promote their existing Supabase user to an Apple or Google identity without losing saved data (preferences, dietary settings, lists, etc.).
- Keep a single Supabase user record; avoid creating a parallel account and migrating data.
- Surface the upgrade action from the Settings sheet with clear status feedback and failure recovery.
- Preserve backwards compatibility for existing full sign-ins (Apple/Google) and legacy guest credentials.

## Non-Goals
- Supporting linking multiple providers per user (e.g., both Apple and Google at once).
- Providing upgrade options outside of the authenticated settings experience.
- Altering server-side Supabase policies beyond what is necessary to permit identity linking.

## Current State Summary
- `AuthController` manages Supabase sessions, exposes `signedInWithApple/Google` and `signedInAsGuest`, and handles anonymous sign-in plus Apple/Google sign-in flows using `signInWithIdToken`.
- Settings UI (`Views/Tabs/SettingsSheet.swift`) shows account actions based on the provider, but anonymous users only see "Reset App State".
- Keychain stores anonymous credentials via `anonEmail` and `anonPassword` to support a legacy login pathway.
- Supabase session change listener (`authStateChanges`) updates `AuthController.session` and `signInState`.

## Proposed Solution

### Supabase Identity Linking
- Use Supabase Auth **linking** to attach a new OAuth provider to the currently authenticated anonymous session instead of signing in fresh. The current `supabase-swift` dependency (v2.34.0) exposes this as `supabaseClient.auth.link`.
- Flow:
  1. Collect provider credentials (Apple identity token or Google ID token) while the user is still signed in anonymously.
  2. Call `auth.link(credentials:)` with the token; Supabase upgrades the user in place and returns an updated `Session`.
  3. Persist the session in `AuthController` and clear any legacy anonymous keychain entries.
- Ensure Supabase dashboard has "Allow linking" enabled for Apple and Google providers and that redirect URIs include the native overrides already used for sign-in.

### Failure Handling & Edge Cases
- `identity_already_exists`: surface the Supabase error, keep the anonymous session active, and instruct the user to sign in with the existing provider or contact support.
- Token acquisition cancelled or missing nonce: bubble the error up to the UI and provide a retry button; do not mutate session state.
- Network or Supabase outage: report the failure, keep the anonymous session untouched, and allow retry; leverage existing loading state to prevent duplicate submissions.
- Expired anonymous session prior to linking: attempt `supabaseClient.auth.refreshSession()` before calling `link`; if refresh fails, inform the user and redirect to re-authenticate anonymously.
- Anonymous credentials cleanup: defer keychain deletion until `auth.link` returns successfully and the new session is stored.
- Concurrent upgrade attempts: track an `isUpgradingAccount` state in `AuthController`/UI to disable other upgrade buttons until the operation completes or fails.
### AuthController Updates
- Introduce an `enum AccountUpgradeProvider { case apple, google }` and a single entry point `upgradeCurrentAccount(to:) async`.
- Refactor existing Apple/Google helpers into shared routines that can operate in **sign-in** or **link** mode:
  - Extract token acquisition (`requestAppleIDToken()` / `requestGoogleIDToken(...)`) from the current sign-in methods.
  - Move Supabase calls into `finalizeAuth(with credentials: OpenIDConnectCredentials, mode: AuthMode)` where `AuthMode` determines whether to call `signInWithIdToken` (fresh login) or `link`.
- On successful upgrade:
  - Update `session`.
  - Clear `anonEmail` / `anonPassword` in the keychain.
  - Flip `signInState` to `.signedIn` (should already occur through `authStateChanges` but keep explicit safety).
  - Emit a Combine/AsyncStream event if other components need to refresh (e.g., `AppState`).
- Errors from Supabase (e.g., provider already linked elsewhere, invalid token) bubble up so the UI can present actionable messaging.

### Settings UI Changes
- In `SettingsSheet`:
  - Replace the anonymous branch with a new `AccountUpgradeSection` component when `authController.signedInAsGuest` is true.
  - Present two buttons—"Upgrade with Apple" and "Upgrade with Google"—that trigger the corresponding upgrade flow.
  - Show loading states while the upgrade is running; disable opposing actions to prevent double submits.
  - On success, display a transient confirmation (e.g., via `appState.feedbackConfig` toast).
  - On failure, surface the error message from `AuthController` in an alert, with guidance to retry or contact support.
- Keep the existing "Reset App State" action accessible but separate so users can still wipe data.

### Keychain & Local State Handling
- After upgrade, remove stored anonymous credentials to prevent reusing them.
- No schema changes needed for in-app stores (`OnboardingState`, `DietaryPreferences`, etc.) because the Supabase user ID remains consistent.
- Consider adding a boolean flag in `UserPreferences` (e.g., `hasUpgradedAccount`) if the UI needs to hide upgrade prompts after success.

### Analytics & Logging
- Emit structured logs in `AuthController` for upgrade attempts, failures, and completion to aid debugging.
- Hook into existing analytics (if any) with events like `account_upgrade_started`, `account_upgrade_completed`, and `account_upgrade_failed` including provider and failure codes (avoid sending tokens).

## Step-by-Step Implementation Plan

Follow these steps on a new branch named `feature/account-upgrade`.

### 1. Preparation
1.1 Create the branch: `git checkout -b feature/account-upgrade` (starting from `main`).  
1.2 Run `xcodebuild build -project IngrediCheck.xcodeproj -scheme IngrediCheck -destination 'platform=iOS Simulator,name=iPhone 15'` to ensure a clean baseline.  
1.3 Skim `AuthController.swift` and `SettingsSheet.swift` to confirm no outstanding conflicts with pending work.

### 2. AuthController Refactor
2.1 Add a new `enum AccountUpgradeProvider { case apple, google }` near existing auth enums.  
2.2 Extract the Apple credential acquisition into a helper (`requestAppleIDToken() async throws -> OpenIDConnectCredentials`) that:
- Configures and launches the `ASAuthorizationController`.
- Returns the `OpenIDConnectCredentials` with provider `.apple`.  
2.3 Extract the Google credential acquisition into `requestGoogleIDToken(from rootViewController: UIViewController) async throws -> OpenIDConnectCredentials`, reusing the existing nonce logic.  
2.4 Introduce an internal `enum AuthFlowMode { case signIn, link }`.  
2.5 Implement `finalizeAuth(with credentials: OpenIDConnectCredentials, mode: AuthFlowMode) async throws` that calls `auth.signInWithIdToken` for `.signIn` and `auth.link(credentials:)` for `.link`.  
2.6 Add `@Published var isUpgradingAccount = false` (or `@MainActor var`) within `AuthController` to track progress.  
2.7 Implement `public func upgradeCurrentAccount(to provider: AccountUpgradeProvider) async`:
- Guard that `session?.user.isAnonymous == true` (or `signedInAsGuest`).  
- Flip `isUpgradingAccount = true` on the main actor.  
- Acquire credentials using the helpers above (running on the main actor for UI).  
- Call `finalizeAuth(..., mode: .link)` from a `Task`.  
- On success: assign the returned session, clear keychain anon credentials, set `isUpgradingAccount = false`, and optionally trigger a toast via `AppState`.  
- On failure: set `isUpgradingAccount = false`, store the error in a property for the UI to display, and do not clear keychain entries.  
2.8 Update existing Apple/Google sign-in entry points to reuse the shared helpers:
- `handleSignInWithAppleCompletion` should call `finalizeAuth(..., mode: .signIn)`.  
- `signInWithGoogle` should use the new Google helper and `finalizeAuth`.  
2.9 Ensure `authChangeWatcher` still updates `session`/`signInState` and verify no duplicate assignments occur after `link`.

### 3. Settings UI Enhancements
3.1 Create `AccountUpgradeSection` in `SettingsSheet.swift` (near other components) that takes `AuthController` as an environment dependency.  
3.2 When `authController.signedInAsGuest` is true, display the section with:
- A descriptive text explaining the benefit of upgrading.  
- Two buttons: `Upgrade with Apple` and `Upgrade with Google`.  
3.3 Wrap button actions in `Task { await authController.upgradeCurrentAccount(to: ...) }`.  
3.4 Bind button disabled states to `authController.isUpgradingAccount`, show a `ProgressView` when true, and present any surfaced errors using `Alert`.  
3.5 Keep `DeleteAccountView` available but visually separated (e.g., different section) so users can still reset their state.  
3.6 Use `appState.feedbackConfig` (or `SimpleToast`) to show success confirmation after upgrading.

### 4. Keychain and Session Handling
4.1 Inside `upgradeCurrentAccount`, call `keychain.delete(anonUserNameKey)` and `keychain.delete(anonPasswordKey)` only after Supabase responds with a successful `Session`.  
4.2 Ensure failures leave keychain entries untouched for future sign-ins.  
4.3 Verify deleting the account (`deleteAccount()`) still clears the keychain—even after upgrade—by testing the flow manually.

### 5. Logging and Analytics
5.1 Add guard-rail `print` statements or structured logs inside `upgradeCurrentAccount` denoting start, success, and error cases.  
5.2 If analytics hooks exist, fire events `account_upgrade_started`, `account_upgrade_succeeded`, and `account_upgrade_failed` with provider metadata (omit tokens).  
5.3 Ensure analytics calls run on the main actor or a safe background queue per existing conventions.

### 6. Testing & Verification
6.1 Write unit tests in `IngrediCheckTests`:
- Mock `SupabaseClient` to assert `auth.link` is called when upgrading.  
- Verify `keychain.delete` runs only after success.  
- Check `isUpgradingAccount` toggles during the flow.  
6.2 Run `xcodebuild test -project IngrediCheck.xcodeproj -scheme IngrediCheck -destination 'platform=iOS Simulator,name=iPhone 15'`.  
6.3 Manual validation:
- Launch as anonymous, upgrade with Apple, confirm preferences persist, and `signedInWithApple` becomes true.  
- Repeat for Google.  
- Trigger failure cases (cancel sign-in, disable network) and confirm the UI recovers gracefully.  
6.4 Document final test results in the PR description.

## Testing Strategy
- **Unit tests**
  - Mock `SupabaseClient` behavior to ensure `upgradeCurrentAccount` calls `link` when `session.user.isAnonymous` is true.
  - Test error propagation and keychain cleanup logic using a test double around `KeychainSwift`.
  - Validate that `signedInAsGuest` transitions to false and `signedInWithApple/Google` flip appropriately.
- **Integration/manual**
  - Simulator run upgrading from anonymous → Apple and anonymous → Google; verify data persistence and session continuity.
  - Attempt upgrade when network offline to confirm retry surfaces.
  - Attempt upgrade with provider already linked to another account; ensure Supabase error appears.
- **Regression**
  - Confirm fresh Apple/Google sign-in still works from cold start (not in upgrade mode).
  - Verify account deletion flows still sign out and clear local state after an upgraded account is deleted.

## Open Questions
- Do we need to display the user's current linked provider(s) after upgrade (e.g., show email or Apple ID under Account)?
- Should we offer a way to unlink and revert to anonymous for troubleshooting?
- Are there analytics or marketing requirements (e.g., prompt after upgrade to collect email preferences)?
