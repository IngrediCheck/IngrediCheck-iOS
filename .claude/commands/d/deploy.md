# Deploy to Device

Build and deploy the app to a connected iOS device or simulator using XcodeBuildMCP.

Target: $ARGUMENTS

## Execution Model

**IMMEDIATELY** spawn a Task subagent to execute this deployment. Do NOT run in the main conversation.

```
Task tool:
  subagent_type: "general-purpose"
  description: "Deploy to iOS device"
  prompt: <include full instructions below, substituting $ARGUMENTS>
```

After the subagent completes, report the result briefly (success/failure, device name).

---

## Subagent Instructions

### MCP Tool Preloading (FIRST)

**CRITICAL:** Load ALL needed MCP tools upfront in ONE parallel batch before doing anything else:
```
MCPSearch: select:mcp__XcodeBuildMCP__list_devices
MCPSearch: select:mcp__XcodeBuildMCP__list_sims
MCPSearch: select:mcp__XcodeBuildMCP__session-set-defaults
MCPSearch: select:mcp__XcodeBuildMCP__build_device
MCPSearch: select:mcp__XcodeBuildMCP__get_device_app_path
MCPSearch: select:mcp__XcodeBuildMCP__install_app_device
MCPSearch: select:mcp__XcodeBuildMCP__launch_app_device
MCPSearch: select:mcp__XcodeBuildMCP__build_sim
MCPSearch: select:mcp__XcodeBuildMCP__get_sim_app_path
MCPSearch: select:mcp__XcodeBuildMCP__install_app_sim
MCPSearch: select:mcp__XcodeBuildMCP__boot_sim
```

This eliminates ~7 sequential round-trips during execution.

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

### Pre-Build Setup (PARALLEL)

Run these in parallel to save time:
- **Bash**: `ls IngrediCheck/Config.swift` - verify exists. If missing, copy from main worktree: `cp "$(git worktree list | head -1 | awk '{print $1}')/IngrediCheck/Config.swift" IngrediCheck/Config.swift`
- **Bash**: `idevice_id -l` - get real device UDID for later log capture
- **Bash**: `pkill -f idevicesyslog 2>/dev/null || true` - clean up any existing log process

### Build & Deploy (XcodeBuildMCP)

**For physical device:**
1. `session-set-defaults` with projectPath, deviceId, **and scheme**
2. `build_device` → if fails, stop and report error
3. `get_device_app_path` → get the .app path
4. `install_app_device` with appPath
5. Start log capture using TWO sequential Bash calls (not one multi-line):
   - **First call**: `nohup idevicesyslog -u <UDID> > /tmp/ingredicheck-logs.txt 2>&1 &`
   - **Second call**: `sleep 2 && ps aux | grep idevicesyslog | grep -v grep && ls -lh /tmp/ingredicheck-logs.txt`

   **IMPORTANT:**
   - Do NOT use `run_in_background: true` parameter - it breaks redirects
   - Do NOT use multi-line commands or newlines between `&&` - they cause parsing issues
   - Do NOT use `-m "IngrediCheck"` filter - it incorrectly filters out some NSLog messages
6. Run in PARALLEL:
   - `launch_app_device` with bundleId to launch the app
   - Bash to save `.claude/debug.txt`: `mkdir -p .claude && echo "device:<targetId>:/tmp/ingredicheck-logs.txt:<realUDID>" > .claude/debug.txt`

**Note:** If log capture fails, `/d:debug` will restart it. Don't block deploy on log issues.

**For simulator:**
1. `session-set-defaults` with projectPath, simulatorId, **and scheme**
2. `boot_sim` (if not already booted)
3. `build_sim` → if fails, stop and report error
4. `get_sim_app_path` → get the .app path
5. `install_app_sim` with appPath
6. Launch app WITH log capture (combines launch + logging in one command):
   ```bash
   nohup xcrun simctl launch --console <simulatorId> llc.fungee.ingredicheck > /tmp/ingredicheck-sim-logs.txt 2>&1 &
   ```
   **NOTE:** Do NOT use `launch_app_sim` - use `simctl launch --console` instead to capture NSLog output.
7. Verify: `sleep 2 && ps aux | grep "simctl launch" | grep -v grep && ls -lh /tmp/ingredicheck-sim-logs.txt`
8. Save to `.claude/debug.txt`: `mkdir -p .claude && echo "sim:<simulatorId>:/tmp/ingredicheck-sim-logs.txt" > .claude/debug.txt`

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
