---
name: asc-publish
description: Archive, build, and upload IngrediCheck to App Store Connect. Use to publish a new build for TestFlight or App Store.
argument-hint: [--skip-upload]
allowed-tools:
  - Bash(*)
---

# Publish to App Store Connect

Archive, create IPA, and upload to App Store Connect.

Arguments: $ARGUMENTS
- (none): Full build and upload
- `--skip-upload`: Build only, don't upload

## Quick Start

```bash
# Full build and upload
.claude/skills/asc-publish/scripts/publish_appstore.sh

# Build only (skip upload)
SKIP_UPLOAD=1 .claude/skills/asc-publish/scripts/publish_appstore.sh
```

## What It Does

1. **Queries App Store Connect** for latest build number
2. **Archives** with `xcodebuild archive` using build number + 1
3. **Creates IPA** from archive
4. **Uploads** via `iTMSTransporter`

**No local project file changes needed!** Build number is determined from ASC and passed to xcodebuild at build time.

## Prerequisites

### 1. Transporter App
Install from Mac App Store: [Transporter](https://apps.apple.com/us/app/transporter/id1450874784)

### 2. Distribution Certificate
- Open Xcode → Settings → Accounts
- Select Apple ID → Manage Certificates
- Create "Apple Distribution" certificate

### 3. App Store Connect API Key
1. Go to [App Store Connect API Keys](https://appstoreconnect.apple.com/access/integrations/api)
2. Create a new key with "App Manager" access
3. Download the `.p8` file (only available once!)
4. Note the Key ID and Issuer ID

### 4. Configure Credentials

Create `.asc/publish.env`:

```bash
mkdir -p .asc
cat > .asc/publish.env << 'EOF'
APP_STORE_CONNECT_API_KEY=YOUR_KEY_ID
APP_STORE_CONNECT_API_ISSUER=YOUR_ISSUER_ID
APP_STORE_CONNECT_API_PRIVATE_KEY_PATH=./AuthKey_YOUR_KEY_ID.p8
APP_STORE_CONNECT_API_KEY_TYPE=individual
EOF
```

Copy your `.p8` key file to `.asc/`:
```bash
cp ~/Downloads/AuthKey_XXXXX.p8 .asc/
```

## Usage

### Full Build & Upload
```bash
.claude/skills/asc-publish/scripts/publish_appstore.sh
```

### Build Only (Test)
```bash
SKIP_UPLOAD=1 .claude/skills/asc-publish/scripts/publish_appstore.sh
```

## Output

```
Using team ID: 58MYNHGN72
Incrementing build number...
Build number set to: 15
Archiving IngrediCheck...
Creating IPA from archive...
IPA created at build/AppStoreExport/IngrediCheck.ipa
Uploading IPA via iTMSTransporter...
=========================================
Upload complete!
Build number: 15
Check App Store Connect for build status.
=========================================
```

## After Upload

Once uploaded, the build will:
1. Process in App Store Connect (few minutes)
2. Appear in TestFlight
3. Be available for internal testers immediately
4. Require Beta App Review for external testers (if not already approved)

Check status with: `/asc-builds`

## Troubleshooting

| Error | Solution |
|-------|----------|
| "Transporter CLI not found" | Install Transporter from Mac App Store |
| "Unable to detect DEVELOPMENT_TEAM" | Set `APPLE_TEAM_ID=58MYNHGN72` in `.asc/publish.env` |
| "Private key file not found" | Check `.p8` file path in `.asc/publish.env` |
| "Authentication credentials invalid" | Verify Key ID and Issuer ID |

## Config

| Variable | Description |
|----------|-------------|
| `APP_STORE_CONNECT_API_KEY` | API Key ID from App Store Connect |
| `APP_STORE_CONNECT_API_ISSUER` | Issuer ID from App Store Connect |
| `APP_STORE_CONNECT_API_PRIVATE_KEY_PATH` | Path to `.p8` file |
| `APP_STORE_CONNECT_API_KEY_TYPE` | `individual` or `team` |
| `APPLE_TEAM_ID` | (optional) Override team ID |
