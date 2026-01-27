#!/bin/bash
# Fast debug log extraction script
# Usage: ./debug-check.sh [device_name]
# Outputs structured data for quick parsing by the agent

set -e

START_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || date +%s)

DEBUG_FILE=".claude/debug.txt"
REQUESTED_DEVICE="${1:-}"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

error() { echo -e "${RED}ERROR:${NC} $1" >&2; exit 1; }

# Check debug.txt exists
[ ! -f "$DEBUG_FILE" ] && error "No debug.txt found. Run /deploy-ios first."

# Temp files for device tracking
ACTIVE_LIST=$(mktemp)
trap "rm -f $ACTIVE_LIST" EXIT

# Parse devices and check which are active
while IFS= read -r line; do
    [ -z "$line" ] && continue
    type="${line%%:*}"

    if [ "$type" = "device" ]; then
        # device:<uuid>:<name>:<logfile>:<udid>
        uuid=$(echo "$line" | cut -d: -f2)
        name=$(echo "$line" | cut -d: -f3)
        logfile=$(echo "$line" | cut -d: -f4)
        udid=$(echo "$line" | cut -d: -f5)

        # Check if active (devicectl console running for this device UUID)
        syslog_running=false
        for pid in $(pgrep -f "devicectl" 2>/dev/null); do
            if ps -p "$pid" -o args= 2>/dev/null | grep -q "$uuid"; then
                syslog_running=true
                break
            fi
        done

        if [ "$syslog_running" = true ] && [ -f "$logfile" ]; then
            echo "$name|device|$logfile|$udid" >> "$ACTIVE_LIST"
        fi
    elif [ "$type" = "sim" ]; then
        # sim:<simid>:<logfile>
        simid=$(echo "$line" | cut -d: -f2)
        logfile=$(echo "$line" | cut -d: -f3)

        if pgrep -f "simctl launch.*$simid" >/dev/null 2>&1 && [ -f "$logfile" ]; then
            echo "simulator|sim|$logfile|$simid" >> "$ACTIVE_LIST"
        fi
    fi
done < "$DEBUG_FILE"

# Check if any devices active
DEVICE_COUNT=$(wc -l < "$ACTIVE_LIST" | tr -d ' ')
if [ "$DEVICE_COUNT" -eq 0 ]; then
    error "No active devices found. Run /deploy-ios first."
fi

# Select device
SELECTED_LINE=""
if [ -n "$REQUESTED_DEVICE" ]; then
    # User specified a device
    SELECTED_LINE=$(grep -i "$REQUESTED_DEVICE" "$ACTIVE_LIST" | head -1)
    [ -z "$SELECTED_LINE" ] && error "Device '$REQUESTED_DEVICE' not active. Active: $(cut -d'|' -f1 "$ACTIVE_LIST" | tr '\n' ' ')"
elif [ "$DEVICE_COUNT" -eq 1 ]; then
    SELECTED_LINE=$(cat "$ACTIVE_LIST")
else
    echo -e "${YELLOW}Multiple active devices:${NC}"
    cut -d'|' -f1 "$ACTIVE_LIST" | while read d; do echo "  - $d"; done
    error "Specify device name as argument"
fi

# Parse selected device
IFS='|' read -r name dtype logfile identifier <<< "$SELECTED_LINE"

echo -e "${CYAN}=== Debug Check: $name ===${NC}"
echo ""

# Log file stats
LOG_SIZE_HUMAN=$(ls -lh "$logfile" 2>/dev/null | awk '{print $5}')
echo -e "${GREEN}Log file:${NC} $logfile ($LOG_SIZE_HUMAN)"

# Count app logs - devicectl console uses [Category] format (not IngrediCheck(Foundation))
# Match lines that start with [ followed by alphanumeric/underscore, then ]
APP_LOG_COUNT=$(grep -aE '^\[[-_A-Za-z0-9]+\]' "$logfile" 2>/dev/null | wc -l | tr -d ' ' || echo 0)
[ -z "$APP_LOG_COUNT" ] && APP_LOG_COUNT=0
echo -e "${GREEN}App log lines:${NC} $APP_LOG_COUNT"

# Extract app logs (last 100 lines max for speed)
echo ""
echo -e "${CYAN}=== App Logs ===${NC}"
if [ "$APP_LOG_COUNT" -gt 0 ] 2>/dev/null; then
    grep -aE '^\[[-_A-Za-z0-9]+\]' "$logfile" | tail -100
else
    echo "(No app logs found - app may not have logged anything yet)"
fi

# Check for errors (only in our app logs, exclude system noise)
echo ""
echo -e "${CYAN}=== Errors ===${NC}"
ERROR_LINES=$(grep -aE '^\[[-_A-Za-z0-9]+\]' "$logfile" 2>/dev/null | grep -a -i "error\|failed\|❌" | tail -20 || true)
if [ -n "$ERROR_LINES" ]; then
    echo "$ERROR_LINES"
else
    echo "(No errors found in app logs)"
fi

# Timing
END_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || date +%s)
DURATION=$((END_TIME - START_TIME))
echo ""
echo -e "${GREEN}Debug check completed in ${DURATION}ms${NC}"
