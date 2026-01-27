---
name: ios-deploy
description: Build and deploy IngrediCheck to iOS device. Use when user wants to deploy, test on device, or run the app.
argument-hint: [target]
allowed-tools:
  - Bash(*)
---

# Deploy to Device

Build and deploy IngrediCheck to a connected iOS device or simulator.

Target: $ARGUMENTS

## Quick Deploy (Recommended)

Run the deploy script directly:

```bash
./.claude/skills/ios-deploy/scripts/deploy-device.sh        # Full build + install
./.claude/skills/ios-deploy/scripts/deploy-device.sh -s     # Skip build, just reinstall
```

The script outputs "Deploy complete in Xs" at the end. Report this total time to the user.

---

## Simulator (target = "sim" or "simulator")

```bash
# Boot simulator if needed
SIMID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
if [ -z "$SIMID" ]; then
  SIMID=$(xcrun simctl list devices available | grep "iPhone" | head -1 | grep -oE '[0-9A-F-]{36}')
  xcrun simctl boot "$SIMID"
fi

# Build, install, launch
xcodebuild -project "IngrediCheck.xcodeproj" -scheme "IngrediCheck" -destination "id=$SIMID" build
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "IngrediCheck.app" -path "*/Debug-iphonesimulator/*" -not -path "*/Index.noindex/*" | head -1)
xcrun simctl install "$SIMID" "$APP_PATH"
nohup xcrun simctl launch --console "$SIMID" llc.fungee.ingredicheck > /tmp/ingredicheck-sim-logs.txt 2>&1 &
mkdir -p .claude && echo "sim:$SIMID:/tmp/ingredicheck-sim-logs.txt" > .claude/debug.txt
```

## Config
- Bundle ID: `llc.fungee.ingredicheck`
- Scheme: `IngrediCheck`
- Project: `IngrediCheck.xcodeproj`
- Team ID: `58MYNHGN72`

## Known Devices
| Name | CoreDevice UUID | UDID |
|------|-----------------|------|
| aadi | 9A624D5C-FA2D-59A1-9CB3-C24FFA4BCAEC | 00008101-000230843A68001E |

## Troubleshooting
- Device must be unlocked and trusted
- If connection errors: unplug/replug USB, or restart device
- Logs: `tail -f /tmp/ingredicheck-logs-<UDID>.txt` (replace `<UDID>` with device UDID)
- Log capture uses `devicectl --console` which reliably captures NSLog on iOS 18+
