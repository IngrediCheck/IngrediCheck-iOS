#!/bin/bash
# Trims log file to keep only the last N minutes of logs
# Usage: log-trimmer.sh <log_file> <minutes> [interval_seconds] [watch_pid]
# Runs continuously, trimming every interval_seconds (default: 30)
# If watch_pid is provided, exits when that process dies (e.g., idevicesyslog)

LOG_FILE="${1:-/tmp/ingredicheck-logs.txt}"
KEEP_MINUTES="${2:-5}"
INTERVAL="${3:-30}"
WATCH_PID="${4:-}"

trim_logs() {
    [ ! -f "$LOG_FILE" ] && return

    # Get cutoff time (N minutes ago)
    CUTOFF=$(date -v-${KEEP_MINUTES}M +"%b %d %H:%M:%S" 2>/dev/null || date -d "${KEEP_MINUTES} minutes ago" +"%b %d %H:%M:%S")

    # Create temp file with only recent logs
    # Log format: "Jan 24 11:28:11.954 ..."
    awk -v cutoff="$CUTOFF" '
    BEGIN {
        split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", months)
        for (i in months) month_num[months[i]] = i
    }
    {
        # Parse log timestamp: "Jan 24 11:28:11.954"
        if (match($0, /^([A-Z][a-z]{2}) +([0-9]+) ([0-9]{2}:[0-9]{2}:[0-9]{2})/, m)) {
            log_ts = sprintf("%02d %02d %s", month_num[m[1]], m[2], m[3])

            # Parse cutoff timestamp
            if (match(cutoff, /^([A-Z][a-z]{2}) +([0-9]+) ([0-9]{2}:[0-9]{2}:[0-9]{2})/, c)) {
                cut_ts = sprintf("%02d %02d %s", month_num[c[1]], c[2], c[3])
            }

            if (log_ts >= cut_ts) print
        } else {
            # Keep lines without recognizable timestamp (continuation lines)
            print
        }
    }' "$LOG_FILE" > "${LOG_FILE}.tmp" 2>/dev/null

    # Only replace if temp file was created successfully
    # Use cat instead of mv to preserve the original file's inode
    # (mv creates a new inode, breaking idevicesyslog's file handle)
    if [ -f "${LOG_FILE}.tmp" ]; then
        cat "${LOG_FILE}.tmp" > "$LOG_FILE"
        rm -f "${LOG_FILE}.tmp"
    fi
}

# Run continuously (exit if watched process dies)
while true; do
    # Exit if watched process died (e.g., idevicesyslog terminated)
    if [ -n "$WATCH_PID" ] && ! kill -0 "$WATCH_PID" 2>/dev/null; then
        exit 0
    fi
    sleep "$INTERVAL"
    trim_logs
done
