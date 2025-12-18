#!/bin/zsh
#
# App Store Distribution Script
#
# This script builds, archives, and uploads the IngrediCheck app to App Store Connect.
# It automatically increments the build number before each upload.
#
# Setup Instructions:
#   1. See publish/README.md for complete setup guide
#   2. Create publish/.env with your App Store Connect API credentials
#   3. Ensure you have Apple Distribution certificate and App Store provisioning profile
#
# Usage:
#   ./publish/publish_appstore.sh              # Full build and upload
#   SKIP_UPLOAD=1 ./publish/publish_appstore.sh  # Build only, skip upload
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLISH_DIR="$SCRIPT_DIR"
PROJECT="${PROJECT:-IngrediCheck.xcodeproj}"
SCHEME="${SCHEME:-IngrediCheck}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$PROJECT_ROOT/build/IngrediCheck.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$PROJECT_ROOT/build/AppStoreExport}"
IPA_NAME="${IPA_NAME:-IngrediCheck}"
IPA_PATH="$EXPORT_PATH/$IPA_NAME.ipa"
EXPORT_PLIST_PATH="$EXPORT_PATH/exportOptions.plist"
PROJECT_PATH="$PROJECT_ROOT/$PROJECT"

if [[ -f "$PUBLISH_DIR/.env" ]]; then
  # shellcheck disable=SC1090
  set -a  # auto-export all variables
  source "$PUBLISH_DIR/.env"
  set +a
fi

cd "$PROJECT_ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode command line tools first." >&2
  exit 1
fi


if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
  echo "Detecting DEVELOPMENT_TEAM from Xcode project..."
  APPLE_TEAM_ID="$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -showBuildSettings 2>/dev/null | awk '/DEVELOPMENT_TEAM/ {print $3; exit}')"
fi

if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
  echo "Unable to detect DEVELOPMENT_TEAM. Set APPLE_TEAM_ID and retry." >&2
  exit 1
fi

echo "Using team ID: $APPLE_TEAM_ID"

if [[ "${SKIP_UPLOAD:-0}" != "1" ]]; then
  : "${APP_STORE_CONNECT_API_KEY:?Set APP_STORE_CONNECT_API_KEY to your App Store Connect API key ID}"
  : "${APP_STORE_CONNECT_API_ISSUER:?Set APP_STORE_CONNECT_API_ISSUER to your App Store Connect issuer ID}"
  : "${APP_STORE_CONNECT_API_PRIVATE_KEY_PATH:?Set APP_STORE_CONNECT_API_PRIVATE_KEY_PATH to your .p8 key file path}"

  # Resolve relative paths against PUBLISH_DIR (where .env lives)
  if [[ "$APP_STORE_CONNECT_API_PRIVATE_KEY_PATH" != /* ]]; then
    APP_STORE_CONNECT_API_PRIVATE_KEY_PATH="$PUBLISH_DIR/$APP_STORE_CONNECT_API_PRIVATE_KEY_PATH"
  fi

  if [[ ! -f "$APP_STORE_CONNECT_API_PRIVATE_KEY_PATH" ]]; then
    echo "Private key file not found at $APP_STORE_CONNECT_API_PRIVATE_KEY_PATH" >&2
    exit 1
  fi

  # altool looks for the API key in ./private_keys/AuthKey_<key_id>.p8
  PRIVATE_KEYS_DIR="$PROJECT_ROOT/private_keys"
  mkdir -p "$PRIVATE_KEYS_DIR"

  EXPECTED_KEY_NAME="AuthKey_${APP_STORE_CONNECT_API_KEY}.p8"
  TARGET_KEY_PATH="$PRIVATE_KEYS_DIR/$EXPECTED_KEY_NAME"
  cp -f "$APP_STORE_CONNECT_API_PRIVATE_KEY_PATH" "$TARGET_KEY_PATH"
  echo "API key copied to $TARGET_KEY_PATH"
fi

echo "Cleaning previous build artifacts..."
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$EXPORT_PATH"

# Get marketing version from project (without modifying it)
MARKETING_VERSION=$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -showBuildSettings 2>/dev/null | awk '/MARKETING_VERSION/ {print $3; exit}')
echo "Marketing version: $MARKETING_VERSION"

# Query App Store Connect for the latest build number (like Xcode does)
echo "Querying App Store Connect for latest build number..."

# Get the bundle ID from the project
BUNDLE_ID=$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -showBuildSettings 2>/dev/null | awk '/^ *PRODUCT_BUNDLE_IDENTIFIER = / {print $3; exit}')
echo "Bundle ID: $BUNDLE_ID"

# Determine build number by querying App Store Connect API
LATEST_BUILD=""

if [[ -n "${APP_STORE_CONNECT_API_KEY:-}" && -n "${APP_STORE_CONNECT_API_ISSUER:-}" && -n "${APP_STORE_CONNECT_API_PRIVATE_KEY_PATH:-}" ]]; then
  LATEST_BUILD=$(python3 << PYTHON_EOF 2>&1
import json
import urllib.request
from datetime import datetime, timedelta, timezone
import sys

try:
    import jwt

    with open("$APP_STORE_CONNECT_API_PRIVATE_KEY_PATH", "r") as f:
        private_key = f.read()

    now = datetime.now(timezone.utc)
    payload = {
        "iss": "$APP_STORE_CONNECT_API_ISSUER",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=20)).timestamp()),
        "aud": "appstoreconnect-v1"
    }
    headers = {"kid": "$APP_STORE_CONNECT_API_KEY", "typ": "JWT"}
    token = jwt.encode(payload, private_key, algorithm="ES256", headers=headers)

    req = urllib.request.Request(
        f"https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]=$BUNDLE_ID",
        headers={"Authorization": f"Bearer {token}"}
    )
    with urllib.request.urlopen(req, timeout=10) as response:
        app_data = json.loads(response.read())

    if app_data.get("data"):
        app_id = app_data["data"][0]["id"]
        # Fetch builds with preReleaseVersion to filter by marketing version
        req = urllib.request.Request(
            f"https://api.appstoreconnect.apple.com/v1/builds?filter[app]={app_id}&include=preReleaseVersion&limit=200",
            headers={"Authorization": f"Bearer {token}"}
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            builds_data = json.loads(response.read())

        # Create a map of preReleaseVersion IDs to version strings
        version_map = {}
        for included in builds_data.get("included", []):
            if included["type"] == "preReleaseVersions":
                version_map[included["id"]] = included["attributes"]["version"]

        # Find the maximum build number for the current marketing version
        # Skip expired builds
        max_build = 0
        target_version = "$MARKETING_VERSION"
        for build in builds_data.get("data", []):
            # Skip expired builds
            if build.get("attributes", {}).get("expired", False):
                continue
            pre_release_data = build.get("relationships", {}).get("preReleaseVersion", {}).get("data")
            if pre_release_data:
                build_marketing_version = version_map.get(pre_release_data["id"], "")
                if build_marketing_version == target_version:
                    try:
                        build_num = int(build["attributes"]["version"])
                        if build_num > max_build:
                            max_build = build_num
                    except (ValueError, KeyError):
                        pass  # Skip non-numeric build numbers
        print(max_build)
    else:
        print("API_ERROR: App not found")
except Exception as e:
    print(f"API_ERROR: {e}")
PYTHON_EOF
)
fi

# Determine new build number
if [[ "$LATEST_BUILD" =~ ^[0-9]+$ ]]; then
  NEW_BUILD=$((LATEST_BUILD + 1))
  if [[ "$LATEST_BUILD" != "0" ]]; then
    echo "Latest uploaded build: $LATEST_BUILD"
  else
    echo "No previous builds found, starting at build 1"
  fi
else
  echo ""
  echo "ERROR: Could not query App Store Connect for latest build number."
  echo "API response: $LATEST_BUILD"
  echo ""
  echo "Your API key may not have permission to query builds."
  echo "Go to App Store Connect > Users and Access > Integrations > App Store Connect API"
  echo "and ensure your API key has 'Admin' or 'App Manager' role."
  echo ""
  exit 1
fi

echo "New build number: $NEW_BUILD"

echo "Archiving $SCHEME from $PROJECT_PATH..."
xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  SKIP_INSTALL=NO \
  CURRENT_PROJECT_VERSION="$NEW_BUILD"

# Fix for Xcode 26 bug: Archive Info.plist is missing ApplicationProperties
# This causes the archive to be a "Generic Xcode Archive" instead of "iOS App Archive"
echo "Fixing archive metadata (Xcode 26 workaround)..."
APP_PATH="$ARCHIVE_PATH/Products/Applications/IngrediCheck.app"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_PATH/Info.plist")
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Info.plist")
APP_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Info.plist")
SIGNING_ID=$(codesign -dvvv "$APP_PATH" 2>&1 | grep "Authority=Apple Distribution" | head -1 | sed 's/Authority=//')

cat > "$ARCHIVE_PATH/Info.plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>ApplicationProperties</key>
	<dict>
		<key>ApplicationPath</key>
		<string>Applications/IngrediCheck.app</string>
		<key>Architectures</key>
		<array>
			<string>arm64</string>
		</array>
		<key>CFBundleIdentifier</key>
		<string>$BUNDLE_ID</string>
		<key>CFBundleShortVersionString</key>
		<string>$APP_VERSION</string>
		<key>CFBundleVersion</key>
		<string>$APP_BUILD</string>
		<key>SigningIdentity</key>
		<string>$SIGNING_ID</string>
		<key>Team</key>
		<string>$APPLE_TEAM_ID</string>
	</dict>
	<key>ArchiveVersion</key>
	<integer>2</integer>
	<key>CreationDate</key>
	<date>$(date -u +%Y-%m-%dT%H:%M:%SZ)</date>
	<key>Name</key>
	<string>$SCHEME</string>
	<key>SchemeName</key>
	<string>$SCHEME</string>
</dict>
</plist>
PLIST_EOF
echo "✓ Archive metadata fixed"

# Create IPA from the archive
# Note: xcodebuild -exportArchive is broken in Xcode 26, so we create the IPA manually
# The archive is already properly signed with App Store distribution credentials
echo "Creating IPA from archive..."
APP_PATH="$ARCHIVE_PATH/Products/Applications/IngrediCheck.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at $APP_PATH" >&2
  exit 1
fi

# Verify the app is signed with distribution certificate
echo "Verifying code signing..."
SIGNING_IDENTITY=$(codesign -dvvv "$APP_PATH" 2>&1 | grep "Authority=Apple Distribution" || true)
if [[ -z "$SIGNING_IDENTITY" ]]; then
  echo "Error: App is not signed with Apple Distribution certificate" >&2
  codesign -dvvv "$APP_PATH" 2>&1 | grep "Authority=" || true
  exit 1
fi
echo "✓ App is signed with Apple Distribution certificate"

# Verify embedded provisioning profile exists
if [[ ! -f "$APP_PATH/embedded.mobileprovision" ]]; then
  echo "Error: No embedded provisioning profile found in app" >&2
  exit 1
fi
echo "✓ Embedded provisioning profile found"

# Verify it's an App Store profile (no ProvisionedDevices key means App Store/Enterprise)
PROFILE_DEVICES=$(security cms -D -i "$APP_PATH/embedded.mobileprovision" 2>/dev/null | grep -c "ProvisionedDevices" || echo "0")
if [[ "$PROFILE_DEVICES" != "0" ]]; then
  echo "Warning: Profile appears to be a development/ad-hoc profile (has device list)"
  echo "For App Store distribution, use an App Store provisioning profile"
fi
PROFILE_NAME=$(security cms -D -i "$APP_PATH/embedded.mobileprovision" 2>/dev/null | grep -A1 "<key>Name</key>" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
echo "✓ Using provisioning profile: $PROFILE_NAME"

# Create Payload directory and copy app
PAYLOAD_DIR="$EXPORT_PATH/Payload"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"

# Create the IPA (it's just a zip with .ipa extension)
cd "$EXPORT_PATH"
zip -r -q "$IPA_NAME.ipa" Payload
rm -rf Payload
cd "$PROJECT_ROOT"

if [[ ! -f "$IPA_PATH" ]]; then
  echo "Failed to create IPA at $IPA_PATH" >&2
  exit 1
fi

echo "✓ IPA created at $IPA_PATH"

if [[ "${SKIP_UPLOAD:-0}" == "1" ]]; then
  echo "SKIP_UPLOAD=1 set; skipping Transporter upload."
  exit 0
fi

echo "Uploading IPA to App Store Connect via iTMSTransporter..."

# Locate iTMSTransporter
TRANSPORTER_CLI=""
if [[ -x /Applications/Transporter.app/Contents/itms/bin/iTMSTransporter ]]; then
  TRANSPORTER_CLI="/Applications/Transporter.app/Contents/itms/bin/iTMSTransporter"
elif command -v iTMSTransporter >/dev/null 2>&1; then
  TRANSPORTER_CLI="$(command -v iTMSTransporter)"
fi

if [[ -z "$TRANSPORTER_CLI" ]]; then
  echo "iTMSTransporter not found. Install the Transporter app from the Mac App Store." >&2
  exit 1
fi

# Setup API key for iTMSTransporter (individual keys use ApiKey_ prefix)
mkdir -p "$PROJECT_ROOT/private_keys"
cp -f "$APP_STORE_CONNECT_API_PRIVATE_KEY_PATH" "$PROJECT_ROOT/private_keys/ApiKey_${APP_STORE_CONNECT_API_KEY}.p8"

"$TRANSPORTER_CLI" -m upload \
  -apiKey "$APP_STORE_CONNECT_API_KEY" \
  -apiIssuer "$APP_STORE_CONNECT_API_ISSUER" \
  -apiKeyType "individual" \
  -assetFile "$IPA_PATH" \
  -v informational

echo ""
echo "✅ Upload complete!"
echo ""
echo "Build $NEW_BUILD (version $MARKETING_VERSION) has been uploaded to App Store Connect."
echo ""
echo "Next steps:"
echo "  1. Check your email for any processing notifications from Apple"
echo "  2. View build status: https://appstoreconnect.apple.com"
echo "  3. Builds typically take 5-30 minutes to process before appearing"
echo ""
echo "If the build doesn't appear after 30 minutes, check for emails from Apple"
echo "about processing errors or compliance issues."

