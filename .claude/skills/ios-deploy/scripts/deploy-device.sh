#!/bin/bash
# Fast iOS deployment script for IngrediCheck
# Usage: ./scripts/deploy-device.sh [--skip-build]

set -e

# Config
PROJECT="IngrediCheck.xcodeproj"
SCHEME="IngrediCheck"
BUNDLE_ID="llc.fungee.ingredicheck"
DEVICE_UUID="9A624D5C-FA2D-59A1-9CB3-C24FFA4BCAEC"
DEVICE_UDID="00008101-000230843A68001E"
TEAM_ID="58MYNHGN72"
LOG_FILE="/tmp/ingredicheck-logs-${DEVICE_UDID}.txt"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[DEPLOY]${NC} $1"; }
warn() { echo -e "${YELLOW}[DEPLOY]${NC} $1"; }
error() { echo -e "${RED}[DEPLOY]${NC} $1"; exit 1; }

# Timeout function for macOS
run_with_timeout() {
    local timeout=$1; shift
    "$@" & local pid=$!
    ( sleep "$timeout"; kill -9 $pid 2>/dev/null ) &
    wait $pid 2>/dev/null
}

START_TIME=$(date +%s)

# Parse args
SKIP_BUILD=false
for arg in "$@"; do
    case $arg in
        --skip-build|-s) SKIP_BUILD=true ;;
    esac
done

# Kill existing log capture and trimmer for THIS device only, truncate log file
# Kill devicectl console processes for this device (uses UUID not UDID)
pkill -f "devicectl device process launch.*$DEVICE_UUID" 2>/dev/null || true
for pid in $(pgrep -x bash 2>/dev/null; pgrep -x zsh 2>/dev/null); do
    if ps -p "$pid" -o args= 2>/dev/null | grep -q "log-trimmer.*${LOG_FILE}"; then
        kill "$pid" 2>/dev/null || true
    fi
done
> "$LOG_FILE"

# Build (unless skipped)
if [ "$SKIP_BUILD" = false ]; then
    log "Building for device..."
    BUILD_START=$(date +%s)

    # Use generic platform - doesn't require device during build
    xcodebuild -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "generic/platform=iOS" \
        -allowProvisioningUpdates \
        CODE_SIGN_STYLE=Automatic \
        CODE_SIGN_IDENTITY="Apple Development" \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        PROVISIONING_PROFILE_SPECIFIER="" \
        build 2>&1 | grep -E "(Build Succeeded|error:|warning:.*error)" || true

    BUILD_END=$(date +%s)
    log "Build completed in $((BUILD_END - BUILD_START))s"
else
    warn "Skipping build (--skip-build)"
fi

# Find app (exclude Index.noindex)
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "IngrediCheck.app" -path "*/Build/Products/Debug-iphoneos/*" -not -path "*/Index.noindex/*" -type d 2>/dev/null | head -1)
[ -z "$APP_PATH" ] && error "App not found in DerivedData! Run a full build first."
log "Found app: $APP_PATH"

# Check device is connected
if ! xcrun devicectl list devices 2>/dev/null | grep -q "$DEVICE_UUID"; then
    warn "Device not found. Checking available devices..."
    xcrun devicectl list devices 2>/dev/null | head -5
    error "Device $DEVICE_UUID not connected"
fi

# Install using devicectl (more reliable than ios-deploy)
log "Installing to device..."
INSTALL_START=$(date +%s)
xcrun devicectl device install app --device "$DEVICE_UUID" "$APP_PATH" 2>&1 || error "Install failed!"
INSTALL_END=$(date +%s)
log "Install completed in $((INSTALL_END - INSTALL_START))s"

# Launch with console capture using script for PTY (devicectl buffers without TTY)
log "Launching app with console capture..."
# Use 'script -F -q' to create a pseudo-TTY with immediate flush
# -F: flush after each write (real-time output)
# -q: quiet mode (no start/stop messages)
nohup script -F -q "$LOG_FILE" xcrun devicectl device process launch --console --terminate-existing --device "$DEVICE_UUID" "$BUNDLE_ID" >/dev/null 2>&1 &
LOG_PID=$!

# Give it time to start and verify the process is running
sleep 2
if ! kill -0 $LOG_PID 2>/dev/null; then
    warn "Console capture may have failed - script process not running"
fi

# Note: log-trimmer disabled for devicectl --console since it captures only NSLog
# (much less verbose than idevicesyslog which captured all system logs)

# Save debug context (multi-device aware)
mkdir -p .claude
DEBUG_FILE=".claude/debug.txt"

# Clean stale entries (where log file doesn't exist or logging process not running)
if [ -f "$DEBUG_FILE" ]; then
    TEMP_DEBUG=$(mktemp)
    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue

        # Parse line type
        type="${line%%:*}"

        if [ "$type" = "sim" ]; then
            # Simulator format: sim:<simulatorId>:<logFilePath>
            simid=$(echo "$line" | cut -d: -f2)
            simlog=$(echo "$line" | cut -d: -f3)
            # Keep if log file exists AND simctl launch is running
            if [ -f "$simlog" ] && pgrep -f "simctl launch.*$simid" >/dev/null 2>&1; then
                echo "$line" >> "$TEMP_DEBUG"
            fi
        elif [ "$type" = "device" ]; then
            # Device format: device:<uuid>:<name>:<logfile>:<udid>
            udid=$(echo "$line" | cut -d: -f5)
            logfile=$(echo "$line" | cut -d: -f4)
            # Skip current device (we'll re-add it)
            [ "$udid" = "$DEVICE_UDID" ] && continue
            # Keep if log file exists AND devicectl console is running for this device
            # Extract UUID from the debug entry (field 2)
            device_uuid=$(echo "$line" | cut -d: -f2)
            syslog_running=false
            for pid in $(pgrep -f "devicectl" 2>/dev/null); do
                if ps -p "$pid" -o args= 2>/dev/null | grep -q "$device_uuid"; then
                    syslog_running=true
                    break
                fi
            done
            if [ -f "$logfile" ] && [ "$syslog_running" = true ]; then
                echo "$line" >> "$TEMP_DEBUG"
            fi
        fi
    done < "$DEBUG_FILE"
    mv "$TEMP_DEBUG" "$DEBUG_FILE"
fi

# Add current device entry
echo "device:$DEVICE_UUID:aadi:$LOG_FILE:$DEVICE_UDID" >> "$DEBUG_FILE"

END_TIME=$(date +%s)
TOTAL=$((END_TIME - START_TIME))

log "========================================="
log "Deploy complete in ${TOTAL}s"
log "Logs: tail -f $LOG_FILE"
log "========================================="
