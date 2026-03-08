#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MAESTRO_DIR="$ROOT_DIR/.maestro"
DERIVED_DATA_PATH="$MAESTRO_DIR/build/DerivedData"
REPORT_DIR="${REPORT_DIR:-$MAESTRO_DIR/reports}"
SIM_NAME="${SIM_NAME:-iPhone 16}"
APP_ID="llc.fungee.ingredicheck"

mkdir -p "$REPORT_DIR"

SIM_JSON="$(xcrun simctl list devices available -j)"
SIM_UDID="${SIM_UDID:-$(SIM_JSON="$SIM_JSON" python3 - "$SIM_NAME" <<'PY'
import json
import os
import sys

target_name = sys.argv[1]
devices = json.loads(os.environ["SIM_JSON"])["devices"]
matches = []
for runtime_devices in devices.values():
    for device in runtime_devices:
        if device.get("name") == target_name and device.get("isAvailable"):
            matches.append(device)

booted = [device for device in matches if device.get("state") == "Booted"]
selected = (booted or matches)
print(selected[0]["udid"] if selected else "")
PY
)}"

if [[ -z "$SIM_UDID" ]]; then
  echo "Could not find an available simulator named '$SIM_NAME'." >&2
  exit 1
fi

open -a Simulator >/dev/null 2>&1 || true

BOOTED_UDIDS="$(xcrun simctl list devices booted -j | python3 - <<'PY'
import json
import sys

data = json.load(sys.stdin)
for runtime_devices in data.get("devices", {}).values():
    for device in runtime_devices:
        if device.get("state") == "Booted":
            print(device["udid"])
PY
)"

while IFS= read -r booted_udid; do
  if [[ -n "$booted_udid" && "$booted_udid" != "$SIM_UDID" ]]; then
    xcrun simctl shutdown "$booted_udid" >/dev/null 2>&1 || true
  fi
done <<< "$BOOTED_UDIDS"

xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_UDID" -b

xcodebuild build \
  -project "$ROOT_DIR/IngrediCheck.xcodeproj" \
  -scheme "IngrediCheck" \
  -destination "id=$SIM_UDID" \
  -derivedDataPath "$DERIVED_DATA_PATH"

APP_PATH="$(find "$DERIVED_DATA_PATH/Build/Products" -path '*Debug-iphonesimulator/IngrediCheck.app' -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "Could not locate built IngrediCheck.app under $DERIVED_DATA_PATH" >&2
  exit 1
fi

xcrun simctl uninstall "$SIM_UDID" "$APP_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIM_UDID" "$APP_PATH"

MAESTRO_ARGS=(
  test
  --config config.yaml
  --format HTML
  --output "$REPORT_DIR/report.html"
  --test-output-dir "$REPORT_DIR/artifacts"
)

if [[ -n "${MAESTRO_INCLUDE_TAGS:-}" ]]; then
  MAESTRO_ARGS+=(--include-tags "$MAESTRO_INCLUDE_TAGS")
fi

if [[ -n "${MAESTRO_EXCLUDE_TAGS:-}" ]]; then
  MAESTRO_ARGS+=(--exclude-tags "$MAESTRO_EXCLUDE_TAGS")
fi

MAESTRO_ARGS+=(flows)

(
  cd "$MAESTRO_DIR"
  maestro "${MAESTRO_ARGS[@]}"
)
