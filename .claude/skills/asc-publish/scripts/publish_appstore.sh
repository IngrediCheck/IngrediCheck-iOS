#!/bin/zsh
#
# App Store Distribution Script
#
# This script builds, archives, and uploads the IngrediCheck app to App Store Connect.
# Build number is auto-determined from App Store Connect (latest + 1).
# No local project file changes needed!
#
# Setup Instructions:
#   1. Create .asc/publish.env with your App Store Connect API credentials
#   2. Ensure you have Apple Distribution certificate and App Store provisioning profile
#   3. Run: asc auth login (for querying latest build)
#
# Usage:
#   .claude/skills/asc-publish/scripts/publish_appstore.sh              # Full build and upload
#   SKIP_UPLOAD=1 .claude/skills/asc-publish/scripts/publish_appstore.sh  # Build only, skip upload
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PROJECT="${PROJECT:-IngrediCheck.xcodeproj}"
SCHEME="${SCHEME:-IngrediCheck}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$PROJECT_ROOT/build/IngrediCheck.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$PROJECT_ROOT/build/AppStoreExport}"
IPA_NAME="${IPA_NAME:-IngrediCheck}"
IPA_PATH="$EXPORT_PATH/$IPA_NAME.ipa"
PROJECT_PATH="$PROJECT_ROOT/$PROJECT"

# Load environment from .asc/publish.env (preferred) or publish/.env (legacy)
if [[ -f "$PROJECT_ROOT/.asc/publish.env" ]]; then
  set -a
  source "$PROJECT_ROOT/.asc/publish.env"
  set +a
  ENV_FILE="$PROJECT_ROOT/.asc/publish.env"
elif [[ -f "$PROJECT_ROOT/publish/.env" ]]; then
  set -a
  source "$PROJECT_ROOT/publish/.env"
  set +a
  ENV_FILE="$PROJECT_ROOT/publish/.env"
else
  ENV_FILE=""
fi

cd "$PROJECT_ROOT"

# Check for required tools
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "❌ xcodebuild not found. Install Xcode command line tools first." >&2
  exit 1
fi

if ! command -v asc >/dev/null 2>&1; then
  echo "❌ asc CLI not found. Install with: brew tap rudrankriyam/tap && brew install asc" >&2
  exit 1
fi

# Load ASC app ID from config
if [[ -f "$PROJECT_ROOT/.asc/config.json" ]]; then
  ASC_APP_ID=$(jq -r '.app_id // empty' "$PROJECT_ROOT/.asc/config.json" 2>/dev/null)
fi

if [[ -z "${ASC_APP_ID:-}" ]]; then
  echo "❌ ASC_APP_ID not configured. Run /asc-setup first." >&2
  exit 1
fi

# Get latest build number from App Store Connect
echo "📡 Fetching latest build from App Store Connect..."
LATEST_BUILD=$(asc builds latest --app "$ASC_APP_ID" 2>/dev/null | jq -r '.data.attributes.version // "0"')

if [[ ! "$LATEST_BUILD" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Could not parse latest build number ('$LATEST_BUILD'), starting from 1"
  LATEST_BUILD=0
fi

NEW_BUILD=$((LATEST_BUILD + 1))
echo "📦 Latest build in ASC: $LATEST_BUILD → New build: $NEW_BUILD"

# Locate iTMSTransporter for upload
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
    echo "❌ iTMSTransporter CLI not found. Install the Transporter app from the Mac App Store." >&2
    exit 1
  fi
fi

# Detect team ID
if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
  APPLE_TEAM_ID="$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -showBuildSettings 2>/dev/null | awk '/DEVELOPMENT_TEAM/ {print $3; exit}')"
fi

if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
  echo "❌ Unable to detect DEVELOPMENT_TEAM. Set APPLE_TEAM_ID and retry." >&2
  exit 1
fi

echo "🔑 Using team ID: $APPLE_TEAM_ID"

# Validate upload credentials
if [[ "${SKIP_UPLOAD:-0}" != "1" ]]; then
  : "${APP_STORE_CONNECT_API_KEY:?Set APP_STORE_CONNECT_API_KEY in .asc/publish.env}"
  : "${APP_STORE_CONNECT_API_ISSUER:?Set APP_STORE_CONNECT_API_ISSUER in .asc/publish.env}"
  : "${APP_STORE_CONNECT_API_PRIVATE_KEY_PATH:?Set APP_STORE_CONNECT_API_PRIVATE_KEY_PATH in .asc/publish.env}"

  # Resolve relative paths
  if [[ -n "$ENV_FILE" && "$APP_STORE_CONNECT_API_PRIVATE_KEY_PATH" != /* ]]; then
    ENV_DIR="$(dirname "$ENV_FILE")"
    APP_STORE_CONNECT_API_PRIVATE_KEY_PATH="$ENV_DIR/$APP_STORE_CONNECT_API_PRIVATE_KEY_PATH"
  fi

  if [[ ! -f "$APP_STORE_CONNECT_API_PRIVATE_KEY_PATH" ]]; then
    echo "❌ Private key file not found at $APP_STORE_CONNECT_API_PRIVATE_KEY_PATH" >&2
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

# Clean and prepare
echo "🧹 Cleaning previous build artifacts..."
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$EXPORT_PATH"

# Archive with build number override (no project file changes!)
echo "🔨 Archiving $SCHEME (build $NEW_BUILD)..."
xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  CURRENT_PROJECT_VERSION="$NEW_BUILD" \
  SKIP_INSTALL=NO

# Create IPA manually (workaround for Xcode 26 exportArchive issues)
echo "📦 Creating IPA from archive..."
APP_PATH="$ARCHIVE_PATH/Products/Applications/IngrediCheck.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ App bundle not found at $APP_PATH" >&2
  exit 1
fi

PAYLOAD_DIR="$EXPORT_PATH/Payload"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"

cd "$EXPORT_PATH"
zip -r -q "$IPA_NAME.ipa" Payload
rm -rf Payload
cd "$PROJECT_ROOT"

if [[ ! -f "$IPA_PATH" ]]; then
  echo "❌ Failed to create IPA at $IPA_PATH" >&2
  exit 1
fi

echo "✅ IPA created at $IPA_PATH"

if [[ "${SKIP_UPLOAD:-0}" == "1" ]]; then
  echo ""
  echo "⏭️  SKIP_UPLOAD=1 set; skipping upload."
  echo "   IPA ready at: $IPA_PATH"
  exit 0
fi

echo "🚀 Uploading IPA via iTMSTransporter..."

"${TRANSPORTER_CLI}" -m upload \
  -apiKey "$APP_STORE_CONNECT_API_KEY" \
  -apiIssuer "$APP_STORE_CONNECT_API_ISSUER" \
  -apiKeyType "$DEFAULT_KEY_KIND" \
  -assetFile "$IPA_PATH" \
  -v informational

echo ""
echo "========================================="
echo "✅ Upload complete!"
echo "   Version: 2.0"
echo "   Build:   $NEW_BUILD"
echo ""
echo "Next steps:"
echo "  • Wait for processing (~5 min)"
echo "  • Check status: /asc-builds"
echo "========================================="
