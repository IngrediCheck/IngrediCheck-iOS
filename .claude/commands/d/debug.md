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
1. Check if idevicesyslog is still running: `ps aux | grep idevicesyslog | grep -v grep`
2. If not running, restart it:
   ```bash
   idevicesyslog -u <UDID> -m "IngrediCheck" 2>/dev/null >> /tmp/ingredicheck-logs.txt &
   ```
3. Read the log file (e.g., `/tmp/ingredicheck-logs.txt`) using the Read tool
4. After reading, truncate for next session: `> /tmp/ingredicheck-logs.txt`
5. **The app keeps running - no restart needed!**

**For simulator (XcodeBuildMCP):**
- `stop_sim_log_cap` with sessionId to get logs
- **If session not found/expired:** Tell user to run `/d:deploy` to start fresh
- After analysis, spawn a background Task to restart log capture

### 3. Analyze Logs

**Log format for custom app logs:**
```
Jan 17 16:09:04.087254 IngrediCheck(Foundation)[1181] <Notice>: [Category] message
```

**Look for:**
- Custom app logs with categories: `[FamilyStore]`, `[WebService]`, `[AUTH]`, `[FamilyAPI]`, `[ScanHistoryStore]`, `[OnboardingPersistence]`, etc.
- Error indicators: `❌`, `error`, `Error`, `failed`, `Failed`
- Network issues: HTTP status codes, `NetworkError`, timeouts, QUIC errors
- Crashes or exceptions

**Filter commands:**
```bash
# Show only custom app logs (with categories)
grep -E "\[FamilyStore\]|\[WebService\]|\[AUTH\]|\[FamilyAPI\]" /tmp/ingredicheck-logs.txt

# Show errors
grep -i "error\|failed\|❌" /tmp/ingredicheck-logs.txt
```

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

## Technical Notes

### Log Utility Architecture
The app uses `Log.debug/info/warning/error()` which internally calls NSLog:
- Located in: `IngrediCheck/Utilities/OnboardingPersistence.swift`
- **Why NSLog?** Apple's os_log/Logger does NOT appear in idevicesyslog due to privacy restrictions
- NSLog output format: `IngrediCheck(Foundation)[PID] <Notice>: [Category] message`

### Key Benefit
For physical devices, the app **continues running** during debug analysis - no restart, no lost state!

### Troubleshooting
- **No logs appearing?** Check if idevicesyslog is running
- **Only system logs?** Custom Log calls use NSLog; if you see `<private>` that's os_log (shouldn't happen)
- **Process died?** Restart with `idevicesyslog -u <UDID> -m "IngrediCheck" >> /tmp/ingredicheck-logs.txt &`
