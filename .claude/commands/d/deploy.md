# Deploy to Device

Build and deploy the app to a connected iOS device or simulator using XcodeBuildMCP.

Target: $ARGUMENTS

## Instructions

### Target Selection

**If reusing last target (no argument):**
1. Read `.claude/debug.txt` for last target (format: `<type>:<targetId>:<sessionId>`)
2. Run `list_devices` (if type=device) or `list_sims` (if type=sim) to verify target exists
3. If target gone → fall through to "ask user"

**If argument provided:**
- `"sim"` or `"simulator"` → run `list_sims`, use first booted or ask user
- `"device"` → run `list_devices`, use first connected or ask user
- Other name → run `list_devices` first, then `list_sims` if not found, match by name

**If target not found:** Ask user which target to use

### Build & Deploy (XcodeBuildMCP)

**For physical device:**
1. `session-set-defaults` with projectPath, deviceId, **and scheme**
2. `build_device` → if fails, stop and report error
3. `get_device_app_path` → get the .app path
4. `install_app_device` with appPath
5. `start_device_log_cap` with bundleId → **also launches the app**
6. Save to `.claude/debug.txt` as `device:<targetId>:<logSessionId>`

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
