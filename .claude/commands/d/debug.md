# Analyze Debug Logs

Read and analyze logs from the running app without restarting it.

User's issue description: $ARGUMENTS

## Execution Model

**IMMEDIATELY** spawn a Task subagent to execute this log analysis. Do NOT run in the main conversation.

```
Task tool:
  subagent_type: "general-purpose"
  description: "Analyze iOS debug logs"
  prompt: <include full instructions below, substituting $ARGUMENTS>
```

After the subagent completes, relay the analysis summary to the user.

---

## Subagent Instructions

### 1. Get Session Info
- Read `.claude/debug.txt`
  - Device format: `device:<targetId>:<logFilePath>:<realUDID>`
  - Simulator format: `sim:<simulatorId>:<logFilePath>`
- **If file missing/malformed:** Tell user to run `/d:deploy` first

### 2. Retrieve Logs

**For physical device (idevicesyslog):**
1. Check if idevicesyslog is still running: `pgrep -f idevicesyslog`
   - **Use `pgrep`** not `ps aux | grep` - more reliable process detection
2. If not running, restart with simple redirect (DO NOT use `run_in_background: true`):
   ```bash
   pkill -f idevicesyslog 2>/dev/null || true
   > /tmp/ingredicheck-logs.txt
   idevicesyslog -u <UDID> > /tmp/ingredicheck-logs.txt 2>&1 &
   sleep 5
   ls -lh /tmp/ingredicheck-logs.txt  # Should be >0 and growing
   head -3 /tmp/ingredicheck-logs.txt  # Verify logs flowing
   ```
   **IMPORTANT:** Run this as a single bash call with inline `&`, NOT with `run_in_background: true` parameter.
   The `run_in_background` parameter breaks redirects. Use a timeout (e.g., 15s) on the bash call.
3. Check log file for **stale logs** (common issue):
   ```bash
   ls -lh /tmp/ingredicheck-logs.txt  # Check size
   grep -a -c "IngrediCheck(Foundation)" /tmp/ingredicheck-logs.txt  # Check for app logs
   ```
   - If large file (>10MB) but 0 app logs → **stale logs**, truncate and wait for fresh logs
   - If 0 bytes → idevicesyslog died, restart it
   - If has app logs → proceed with analysis
4. Filter and read app logs using grep -a (binary mode since file may contain binary data):
   ```bash
   grep -a "IngrediCheck(Foundation)" /tmp/ingredicheck-logs.txt
   ```
5. After reading AND analysis, truncate for next session: `> /tmp/ingredicheck-logs.txt`
   - **Important:** Truncate AFTER you've extracted all needed info
6. **The app keeps running - no restart needed!**

**For simulator (file-based, same as device):**
1. Check if log capture is running: `pgrep -f "simctl launch"`
2. If not running, restart (this also relaunches the app):
   ```bash
   xcrun simctl terminate <simulatorId> llc.fungee.ingredicheck 2>/dev/null || true
   nohup xcrun simctl launch --console <simulatorId> llc.fungee.ingredicheck > /tmp/ingredicheck-sim-logs.txt 2>&1 &
   sleep 3
   ```
   **NOTE:** `simctl launch --console` captures NSLog output. Do NOT use `log stream` - it doesn't capture NSLog.
3. Check and filter logs the same way as device:
   ```bash
   ls -lh /tmp/ingredicheck-sim-logs.txt
   cat /tmp/ingredicheck-sim-logs.txt
   ```
4. Truncate after analysis: `> /tmp/ingredicheck-sim-logs.txt`

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

**Filter commands (use -a for binary mode):**
```bash
# Show only custom app logs (Foundation = our NSLog calls)
grep -a "IngrediCheck(Foundation)" /tmp/ingredicheck-logs.txt

# Show specific categories (add more as needed)
grep -a -E "\[FamilyStore\]|\[WebService\]|\[AUTH\]|\[SCAN_HISTORY\]|\[ScanHistoryStore\]|\[HomeView\]|\[BARCODE_SCAN\]|\[FoodNotes\]" /tmp/ingredicheck-logs.txt

# Show errors
grep -a -i "error\|failed\|❌" /tmp/ingredicheck-logs.txt

# Show API latency (useful for performance debugging)
grep -a "latency:" /tmp/ingredicheck-logs.txt

# Live tail mode (for real-time debugging - run in separate terminal)
tail -f /tmp/ingredicheck-logs.txt | grep -a "IngrediCheck(Foundation)"
```

### 4. Summarize Findings

**Output your analysis summary:**
- What went wrong (or "no errors found")
- Relevant log excerpts
- Root cause analysis
- Suggested fix if apparent
- End with: "Ready for next issue. Run `/d:debug` again when needed."

## Config
- Bundle ID: `llc.fungee.ingredicheck`
- Log file (device): `/tmp/ingredicheck-logs.txt`
- Log file (simulator): `/tmp/ingredicheck-sim-logs.txt`

## Technical Notes

### Log Utility Architecture
The app uses `Log.debug/info/warning/error()` which internally calls NSLog:
- Located in: `IngrediCheck/Utilities/OnboardingPersistence.swift`
- **Why NSLog?** Apple's os_log/Logger does NOT appear in idevicesyslog due to privacy restrictions
- NSLog output format: `IngrediCheck(Foundation)[PID] <Notice>: [Category] message`

### Key Benefit
For physical devices, the app **continues running** during debug analysis - no restart, no lost state!

### Quick Diagnostics Checklist
Run these in order when logs seem missing or wrong:
```bash
# 1. Is idevicesyslog running?
pgrep -f idevicesyslog

# 2. Is the log file being written to?
ls -lh /tmp/ingredicheck-logs.txt

# 3. Is the device connected?
idevice_id -l

# 4. Any app logs at all? (0 = stale logs, need to truncate and wait)
grep -a -c "IngrediCheck(Foundation)" /tmp/ingredicheck-logs.txt

# 5. Quick peek at app logs
grep -a "IngrediCheck(Foundation)" /tmp/ingredicheck-logs.txt | tail -20
```

### Troubleshooting
- **No logs appearing?** Check if idevicesyslog is running: `pgrep -f idevicesyslog`
- **Log file empty (0 bytes)?** idevicesyslog may have died immediately - check device connection with `idevice_id -l`
- **Large file but 0 app logs?** Stale logs from before app launched - truncate with `> /tmp/ingredicheck-logs.txt` and wait
- **Only system logs?** Custom Log calls use NSLog; if you see `<private>` that's os_log (shouldn't happen)
- **Binary file warning from grep?** Use `grep -a` flag for binary mode
- **Process died?** Restart with: `idevicesyslog -u <UDID> > /tmp/ingredicheck-logs.txt 2>&1 &` (in single bash call with sleep/verify)
- **Device locked?** Unlock the device - idevicesyslog may not capture logs when locked
- **Claude Code `run_in_background` breaks redirects?** Do NOT use `run_in_background: true` parameter. Use inline `&` with verification in same bash call.
- **IMPORTANT:** Do NOT use `-m "IngrediCheck"` filter - it incorrectly filters out some NSLog messages
