# Repository Guidelines

## Project Structure & Module Organization
- App sources live under `IngrediCheck/`; SwiftUI screens sit in `Views/`, shared helpers in `Utilities/`, and observable state in `Store/` (e.g., `AuthController.swift`, `NetworkState.swift`).
- Network access is handled by `WebService.swift` and `SupabaseRequestBuilder.swift`; keep API DTOs in `DTO.swift` to share models across features.
- Assets and localized imagery are managed inside `Assets.xcassets`; update catalog groups rather than adding ad-hoc bundles.
- Configuration constants (Supabase endpoints, analytics keys) are defined in `Config.swift`; use environment-specific overrides before shipping secrets.
## Build, Test, and Development Commands
- `xed IngrediCheck.xcodeproj` — open the Xcode project.
- `xcodebuild build -project IngrediCheck.xcodeproj -scheme IngrediCheck -destination 'platform=iOS Simulator,name=iPhone 15'` — CI-friendly build to catch compile issues.
- `xcodebuild test -project IngrediCheck.xcodeproj -scheme IngrediCheck -destination 'platform=iOS Simulator,name=iPhone 15'` — execute unit/UI tests once targets exist.

## Coding Style & Naming Conventions
- Follow Swift 5.9 defaults: four-space indentation, 120-char line guidance, and use trailing commas for multiline literals.
- Types use `UpperCamelCase`, methods/properties use `lowerCamelCase`, and SwiftUI view files match the primary view name (e.g., `DisclaimerView.swift`).
- Group extensions and previews with `// MARK:` comments for discoverability; prefer protocol-oriented patterns for shared behavior.
- Run Xcode's “Re-Indent” and enable `swiftformat` or `SwiftLint` locally; do not commit warnings.

## Testing Guidelines
- Create `IngrediCheckTests` and `IngrediCheckUITests` targets for new coverage; mirror production folder names to keep scopes clear.
- Use `XCTest` naming `test<Scenario>_<ExpectedBehavior>` and include async tests for Supabase/network flows.
- Mock network dependencies via `WebService` protocols to avoid live Supabase hits; capture fixtures under `Tests/Fixtures`.
- Aim for coverage of state stores (auth, onboarding, dietary preferences) and UI flows gating onboarding/consent screens.

## Commit & Pull Request Guidelines
- Prefer conventional titles with a leading area tag (`Feature:`, `Fix:`, `Chore:`) and optional issue references, mirroring recent history (`Feature: Switch to SSE API (#8)`).
- Keep commits scoped to a single concern and include rationale in the body when touching config, analytics, or secrets.
- PRs should summarize functional changes, list test evidence (`xcodebuild build`, `xcodebuild test`), link Supabase/issue tracker tasks, and add screenshots for UI updates.
- Request at least one review, resolve Xcode warnings before merging, and ensure build settings remain in sync.

## Work Tracking
We track work in Beads instead of Markdown. Run \`bd quickstart\` to see how.