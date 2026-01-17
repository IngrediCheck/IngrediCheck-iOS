# Deploy to Device

Build and deploy the app to a connected iOS device or simulator using XcodeBuildMCP.

Target: $ARGUMENTS

## Instructions

### Target Selection

**If reusing last target (no argument):**
1. Read `.claude/debug.txt` for last target (format varies by type, see below)
2. Run `list_devices` (if type=device) or `list_sims` (if type=sim) to verify target exists
3. If target gone → fall through to "ask user"

**If argument provided:**
- `"sim"` or `"simulator"` → run `list_sims`, use first booted or ask user
- `"device"` → run `list_devices`, use first connected or ask user
- Other name → run `list_devices` first, then `list_sims` if not found, match by name

**If target not found:** Ask user which target to use

### Pre-Build: Config.swift Check

Before building, check if `IngrediCheck/Config.swift` exists in this worktree:
1. If missing, find the main worktree via `git worktree list`
2. Copy `Config.swift` from the main worktree's `IngrediCheck/` folder
3. If main worktree also lacks it, warn user and stop

### Build & Deploy (XcodeBuildMCP)

**For physical device:**
1. `session-set-defaults` with projectPath, deviceId, **and scheme**
2. `build_device` → if fails, stop and report error
3. `get_device_app_path` → get the .app path
4. `install_app_device` with appPath
5. Get real device UDID via `idevice_id -l` (libimobiledevice)
6. Kill any existing idevicesyslog process: `pkill -f idevicesyslog 2>/dev/null || true`
7. Start log capture in background:
   ```bash
   idevicesyslog -u <UDID> -m "IngrediCheck" 2>/dev/null >> /tmp/ingredicheck-logs.txt &
   ```
   Note: Use `-m "IngrediCheck"` filter for efficiency (filters at source)
8. `launch_app_device` with bundleId to launch the app
9. Save to `.claude/debug.txt` as `device:<targetId>:/tmp/ingredicheck-logs.txt:<realUDID>`

**For simulator:**
1. `session-set-defaults` with projectPath, simulatorId, **and scheme**
2. `boot_sim` (if not already booted)
3. `build_sim` → if fails, stop and report error
4. `get_sim_app_path` → get the .app path
5. `install_app_sim` with appPath
6. `start_sim_log_cap` with bundleId → **also launches the app**
7. Save to `.claude/debug.txt` as `sim:<targetId>:<logSessionId>`

Tell user: "Deployed with log capture. Run `/d:debug` when you hit an issue."

## Config
- Bundle ID: `llc.fungee.ingredicheck`
- Scheme: `IngrediCheck`
- Project: `IngrediCheck.xcodeproj`

## Technical Notes

### Device ID Mapping
XcodeBuildMCP uses CoreDevice UUIDs (e.g., `9A624D5C-FA2D-59A1-9CB3-C24FFA4BCAEC`) while
libimobiledevice/idevicesyslog uses actual device UDIDs (e.g., `00008101-000230843A68001E`).
Use `idevice_id -l` to get the real UDID for log capture.

### Logging Architecture
The app uses a `Log` utility (in `OnboardingPersistence.swift`) that wraps NSLog:
- **Why NSLog?** Apple's os_log/Logger does NOT appear in idevicesyslog due to privacy restrictions
- **NSLog works** and messages appear as: `IngrediCheck(Foundation)[PID] <Notice>: [Category] message`
- Categories: `[FamilyStore]`, `[WebService]`, `[AUTH]`, `[FamilyAPI]`, `[ScanHistoryStore]`, etc.

### Troubleshooting idevicesyslog
- If logs aren't captured, verify idevicesyslog is running: `ps aux | grep idevicesyslog`
- If process dies, restart it manually or redeploy
- Device must be unlocked and trusted by the host computer
