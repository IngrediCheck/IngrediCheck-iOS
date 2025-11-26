## iOS Fastlane & CI/CD

### Lanes

- **ci_tests**: runs tests for the `IngrediCheck` scheme on an iOS simulator.
- **ci_pr**: aggregates CI checks for pull requests (currently just `ci_tests`).
- **beta**: builds a TestFlight beta using Match-managed signing and uploads via `pilot`.
- **release**: builds and uploads a Release build to App Store Connect via `deliver`.

### Local usage

From the repo root:

```bash
bundle install
bundle exec fastlane ios ci_tests
bundle exec fastlane ios beta
bundle exec fastlane ios release
```

### Required secrets (CI)

- **APPLE_ID**: Apple ID used for App Store Connect.
- **MATCH_GIT_URL**: Git URL of the Match certificates repo.
- **MATCH_PASSWORD**: Encryption password for the Match repo.
- **ITC_TEAM_ID**: App Store Connect Team ID.
- **DEV_PORTAL_TEAM_ID**: Apple Developer Portal Team ID.

### Branch protection for `main`

In GitHub repository settings, configure a branch protection rule for `main` that:

- Requires pull requests before merging (no direct pushes).
- Requires the **iOS CI** workflow (status check from `ios-ci.yml`) to pass.
- Optionally requires at least one approving review and up-to-date branches.


