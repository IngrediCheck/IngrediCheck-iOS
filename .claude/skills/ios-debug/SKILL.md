---
name: ios-debug
description: Analyze debug logs from running IngrediCheck app. Use when debugging issues, checking errors, or user reports a problem.
argument-hint: [issue description]
context: fork
agent: general-purpose
model: haiku
---

# Analyze Debug Logs

User's issue: $ARGUMENTS

---

## CRITICAL: Follow These Steps EXACTLY

**DO NOT** do your own analysis. **ONLY** run the helper script and summarize its output.

### Step 1: Run the Helper Script

```bash
.claude/skills/ios-debug/scripts/debug-check.sh
```

If user specified a device name in their query, pass it as argument:
```bash
.claude/skills/ios-debug/scripts/debug-check.sh aadi
```

### Step 2: Summarize the Output

Based on the script output, provide a **brief** summary:
- If errors found: list them with relevant context
- If no errors: say "No errors found in app logs"
- If no app logs: say "No app logs captured yet"
- Answer the user's specific question if possible

**Keep response concise.** The script already shows the logs - don't repeat them verbatim.

### Step 3: Done

End with: "Debug check completed in Xms" (from script output)

---

## Only If Script Fails

If the helper script errors with "No active devices", tell user to run `/deploy-ios` first.

If the script shows 0 app logs but user needs logs, suggest:
```bash
./.claude/skills/ios-deploy/scripts/deploy-device.sh -s
```

---

## DO NOT

- Do NOT run additional grep/analysis commands unless explicitly asked
- Do NOT analyze system logs (Network, CFNetwork, etc.) - only app logs matter
- Do NOT give lengthy explanations about how logging works
- Do NOT run multiple tool calls - one script call should be enough

## Config
- Bundle ID: `llc.fungee.ingredicheck`
- Log file (device): `/tmp/ingredicheck-logs-<UDID>.txt` (per-device)
- Log file (simulator): `/tmp/ingredicheck-sim-logs.txt`

## Technical Notes

### Log Utility Architecture
The app uses `Log.debug/info/warning/error()` which internally calls NSLog:
- **Why NSLog?** Apple's os_log/Logger does NOT appear in idevicesyslog due to privacy restrictions
- NSLog output format: `IngrediCheck(Foundation)[PID] <Notice>: [Category] message`

### Key Benefit
For physical devices, the app **continues running** during debug analysis - no restart, no lost state!

### Quick Diagnostics Checklist
Run these in order when logs seem missing or wrong (replace `<UDID>` with actual device UDID):
```bash
# 1. Is idevicesyslog running for this device?
pgrep -f "idevicesyslog.*<UDID>"

# 2. Is the log file being written to?
ls -lh /tmp/ingredicheck-logs-<UDID>.txt

# 3. Is the device connected?
idevice_id -l

# 4. Any app logs at all? (0 = stale logs, need to truncate and wait)
grep -a -c "IngrediCheck(Foundation)" /tmp/ingredicheck-logs-<UDID>.txt

# 5. Quick peek at app logs
grep -a "IngrediCheck(Foundation)" /tmp/ingredicheck-logs-<UDID>.txt | tail -20
```

### Troubleshooting
- **No logs appearing?** Check if idevicesyslog is running for the device: `pgrep -f "idevicesyslog.*<UDID>"`
- **Log file empty (0 bytes)?** idevicesyslog may have died immediately - check device connection with `idevice_id -l`
- **Large file but 0 app logs?** Stale logs from before app launched - truncate with `> /tmp/ingredicheck-logs-<UDID>.txt` and wait
- **Only system logs?** Custom Log calls use NSLog; if you see `<private>` that's os_log (shouldn't happen)
- **Binary file warning from grep?** Use `grep -a` flag for binary mode
- **Process died?** Restart with: `idevicesyslog -u <UDID> > /tmp/ingredicheck-logs-<UDID>.txt 2>&1 &` (in single bash call with sleep/verify)
- **Device locked?** Unlock the device - idevicesyslog may not capture logs when locked
- **Claude Code `run_in_background` breaks redirects?** Do NOT use `run_in_background: true` parameter. Use inline `&` with verification in same bash call.
- **Multiple devices?** Each device has its own log file. Check `.claude/debug.txt` for active devices.
- **IMPORTANT:** Do NOT use `-m "IngrediCheck"` filter - it incorrectly filters out some NSLog messages
