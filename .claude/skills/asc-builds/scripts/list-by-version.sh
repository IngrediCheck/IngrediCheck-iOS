#!/bin/bash
# List builds grouped by marketing version with TestFlight status
# Usage: ./list-by-version.sh [num_versions] [builds_per_version]

set -e

source "$(dirname "$0")/../../scripts/asc-common.sh"
asc_load_config

NUM_VERSIONS="${1:-2}"
BUILDS_PER_VERSION="${2:-3}"

# Get recent versions
VERSIONS=$(asc versions list --app "$ASC_APP_ID" | jq -r ".data[:$NUM_VERSIONS][] | \"\(.id)|\(.attributes.versionString)\"")
BUILDS_JSON=$(asc builds list --app "$ASC_APP_ID" --limit 50)

echo "Version | Build        | Uploaded   | External"
echo "--------|--------------|------------|------------------"

echo "$VERSIONS" | while IFS='|' read vid ver; do
  # Get version state and creation date
  VER_INFO=$(asc versions get --version-id "$vid" --include-build 2>/dev/null)
  STATE=$(echo "$VER_INFO" | jq -r '.state')
  CREATED=$(asc versions list --app "$ASC_APP_ID" | jq -r --arg v "$ver" '.data[] | select(.attributes.versionString == $v) | .attributes.createdDate')
  CREATED_TS=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${CREATED:0:19}" "+%s" 2>/dev/null || echo "0")

  if [ "$STATE" = "PREPARE_FOR_SUBMISSION" ]; then
    # Current version: get most recent builds
    echo "$BUILDS_JSON" | jq -r --argjson limit "$BUILDS_PER_VERSION" '.data[:$limit][] | "\(.id)|\(.attributes.version)|\(.attributes.uploadedDate[:10])"'
  else
    # Released version: get builds from 45 days before version creation
    WINDOW_START=$((CREATED_TS - 3888000))
    echo "$BUILDS_JSON" | jq -r --argjson start "$WINDOW_START" --argjson end "$CREATED_TS" --argjson limit "$BUILDS_PER_VERSION" '
      [.data[] |
      (.attributes.uploadedDate[:19] | strptime("%Y-%m-%dT%H:%M:%S") | mktime) as $ts |
      select($ts >= $start and $ts <= $end)] |
      sort_by(.attributes.uploadedDate) | reverse |
      .[:$limit][] |
      "\(.id)|\(.attributes.version)|\(.attributes.uploadedDate[:10])"
    '
  fi | while IFS='|' read id build date; do
    # Get TestFlight beta details
    beta=$(asc testflight beta-details get --build "$id" 2>/dev/null)
    external=$(echo "$beta" | jq -r '.data[0].attributes.externalBuildState // "N/A"')
    printf "%-7s | %-12s | %s | %s\n" "$ver" "$build" "$date" "$external"
  done
done
