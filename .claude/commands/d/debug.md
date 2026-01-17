# Analyze Debug Logs

Read and analyze logs from the running app without restarting it.

User's issue description: $ARGUMENTS

## Instructions

### 1. Get Session Info
- Read `.claude/debug.txt`
  - Device format: `device:<targetId>:<logFilePath>:<realUDID>`
  - Simulator format: `sim:<targetId>:<sessionId>`
- **If file missing/malformed:** Tell user to run `/d:deploy` first

### 2. Retrieve Logs

**For physical device (idevicesyslog):**
- Read the log file (e.g., `/tmp/ingredicheck-logs.txt`) using the Read tool
- The log file contains continuous output from idevicesyslog filtered for "ingredicheck"
- After reading, truncate the file for the next debug session: `> /tmp/ingredicheck-logs.txt`
- **The app keeps running - no restart needed!**

**For simulator (XcodeBuildMCP):**
- `stop_sim_log_cap` with sessionId to get logs
- **If session not found/expired:** Tell user to run `/d:deploy` to start fresh
- After analysis, spawn a background Task to restart log capture

### 3. Analyze Logs
Look for:
- Errors: `❌`, `error`, `Error`, `failed`, `Failed`
- Network: HTTP status codes, `NetworkError`, timeouts
- Crashes or exceptions
- Log categories: `[BARCODE_SCAN]`, `[SCAN_HISTORY]`, `[FamilyStore]`, `[WebService]`, `[AUTH]`, `[PHOTO_SCAN]`, `[FAVORITE]`, etc.

### 4. Summarize Findings

**Output your analysis summary:**
- What went wrong (or "no errors found")
- Relevant log excerpts
- Root cause analysis
- Suggested fix if apparent
- End with: "Ready for next issue. Run `/d:debug` again when needed."

**For simulator only:** Spawn a background Task agent to restart log capture.

## Config
- Bundle ID: `llc.fungee.ingredicheck`
- Log file (device): `/tmp/ingredicheck-logs.txt`

## Key Benefit

For physical devices, the app **continues running** during debug analysis - no restart, no lost state!
