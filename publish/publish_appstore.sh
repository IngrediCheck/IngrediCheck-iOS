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

# Locate iTMSTransporter for upload (used later if not skipping upload)
if [[ "${SKIP_UPLOAD:-0}" != "1" ]]; then
  if [[ -z "${TRANSPORTER_CLI:-}" ]]; then
    if [[ -x /Applications/Transporter.app/Contents/itms/bin/iTMSTransporter ]]; then
      TRANSPORTER_CLI="/Applications/Transporter.app/Contents/itms/bin/iTMSTransporter"
    elif command -v iTMSTransporter >/dev/null 2>&1; then
      TRANSPORTER_CLI="$(command -v iTMSTransporter)"
    else
      TRANSPORTER_CLI="$(xcrun --find iTMSTransporter 2>/dev/null || true)"
    fi
  fi

  if [[ -z "${TRANSPORTER_CLI:-}" ]]; then
    echo "iTMSTransporter CLI not found. Install the Transporter app from the Mac App Store." >&2
    exit 1
  fi
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

  PRIVATE_KEYS_DIR="$PROJECT_ROOT/private_keys"
  mkdir -p "$PRIVATE_KEYS_DIR"

  DEFAULT_KEY_KIND="${APP_STORE_CONNECT_API_KEY_TYPE:-individual}"
  if [[ "$DEFAULT_KEY_KIND" != "team" ]]; then
    DEFAULT_KEY_KIND="individual"
  fi

  EXPECTED_KEY_NAME="ApiKey_${APP_STORE_CONNECT_API_KEY}.p8"
  if [[ "$DEFAULT_KEY_KIND" == "team" ]]; then
    EXPECTED_KEY_NAME="AuthKey_${APP_STORE_CONNECT_API_KEY}.p8"
  fi

  TARGET_KEY_PATH="$PRIVATE_KEYS_DIR/$EXPECTED_KEY_NAME"
  cp -f "$APP_STORE_CONNECT_API_PRIVATE_KEY_PATH" "$TARGET_KEY_PATH"
fi

echo "Cleaning previous build artifacts..."
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$EXPORT_PATH"

# Auto-increment build number (like Xcode does on manual upload)
echo "Incrementing build number..."
cd "$PROJECT_ROOT/IngrediCheck.xcodeproj/.."
CURRENT_BUILD=$(agvtool what-version -terse 2>/dev/null || echo "0")
# Handle non-integer build numbers (e.g., "1.0" -> use timestamp instead)
if [[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]]; then
  NEW_BUILD=$((CURRENT_BUILD + 1))
else
  # Use timestamp-based build number if current isn't a simple integer
  NEW_BUILD=$(date +%Y%m%d%H%M)
fi
agvtool new-version -all "$NEW_BUILD" >/dev/null 2>&1
echo "Build number set to: $NEW_BUILD"
cd "$PROJECT_ROOT"

echo "Archiving $SCHEME from $PROJECT_PATH..."
xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  SKIP_INSTALL=NO

# Create IPA manually from the archive (workaround for Xcode 26 exportArchive issues)
echo "Creating IPA from archive..."
APP_PATH="$ARCHIVE_PATH/Products/Applications/IngrediCheck.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at $APP_PATH" >&2
  exit 1
fi

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

echo "IPA created at $IPA_PATH"

if [[ "${SKIP_UPLOAD:-0}" == "1" ]]; then
  echo "SKIP_UPLOAD=1 set; skipping Transporter upload."
  exit 0
fi

echo "Uploading IPA via iTMSTransporter..."

"${TRANSPORTER_CLI}" -m upload \
  -apiKey "$APP_STORE_CONNECT_API_KEY" \
  -apiIssuer "$APP_STORE_CONNECT_API_ISSUER" \
  -apiKeyType "$DEFAULT_KEY_KIND" \
  -assetFile "$IPA_PATH" \
  -v informational

echo "Upload complete. Check App Store Connect for build status."

