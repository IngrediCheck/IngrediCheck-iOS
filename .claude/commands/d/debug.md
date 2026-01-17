# Analyze Debug Logs

Stop log capture, analyze logs, and restart capture for next issue.

User's issue description: $ARGUMENTS

## Instructions

### 1. Get Session Info
- Read `.claude/debug.txt` (format: `<type>:<targetId>:<sessionId>`)
- **If file missing/malformed:** Tell user to run `/d:deploy` first

### 2. Stop & Retrieve Logs (XcodeBuildMCP)
- Device: `stop_device_log_cap` with sessionId
- Simulator: `stop_sim_log_cap` with sessionId
- **If session not found/expired:** Tell user to run `/d:deploy` to start fresh

### 3. Analyze Logs
Look for:
- Errors: `❌`, `error`, `Error`, `failed`, `Failed`
- Network: HTTP status codes, `NetworkError`, timeouts
- Crashes or exceptions
- App prefixes: `[BARCODE_SCAN]`, `[SCAN_CARD]`, `[FamilyStore]`, `[WebService]`, `[FamilyAPI]`, `[AUTH]`, etc.

### 4. Summarize Findings
- What went wrong (or "no errors found")
- Relevant log excerpts
- Root cause analysis
- Suggested fix if apparent

### 5. Restart Log Capture (XcodeBuildMCP)
- Device: `start_device_log_cap` with bundleId
- Simulator: `start_sim_log_cap` with bundleId
- This also relaunches the app

### 6. Update State
- Write new sessionId to `.claude/debug.txt` (keep same type and targetId)
- Tell user: "Ready for next issue. Run `/d:debug` again when needed."

## Config
- Bundle ID: `llc.fungee.ingredicheck`
