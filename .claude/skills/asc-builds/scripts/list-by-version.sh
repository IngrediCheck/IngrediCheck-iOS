#!/bin/bash
# List builds grouped by marketing version
# Usage: ./list-by-version.sh [num_versions] [builds_per_version]

set -e

source "$(dirname "$0")/../../scripts/asc-common.sh"
asc_load_config

NUM_VERSIONS="${1:-2}"
BUILDS_PER_VERSION="${2:-3}"

# Get recent versions with creation dates
VERSIONS_JSON=$(asc versions list --app "$ASC_APP_ID" | jq "[.data[:$((NUM_VERSIONS + 1))][] | {id: .id, version: .attributes.versionString, created: .attributes.createdDate}]")

# Get recent builds
BUILDS_JSON=$(asc builds list --app "$ASC_APP_ID" --limit 50 | jq '[.data[] | {id: .id, build: .attributes.version, uploaded: .attributes.uploadedDate, state: .attributes.processingState}]')

# Process each version
echo "$VERSIONS_JSON" | jq -r ".[:$NUM_VERSIONS][] | \"\(.version)|\(.created)|\(.id)\"" | while IFS='|' read ver created ver_id; do
  echo ""
  echo "═══ Version $ver ═══"

  # Get the submitted build
  SUBMITTED_BUILD=$(asc versions get --version-id "$ver_id" --include-build 2>/dev/null | jq -r '.buildVersion // "none"')

  if [ "$SUBMITTED_BUILD" != "none" ] && [ "$SUBMITTED_BUILD" != "null" ]; then
    echo "  Submitted: Build $SUBMITTED_BUILD"
  else
    echo "  Submitted: (none yet)"
  fi

  # Get version state to check if it's the current (unsubmitted) version
  VERSION_STATE=$(asc versions get --version-id "$ver_id" --include-build 2>/dev/null | jq -r '.state // ""')

  echo ""
  echo "  Recent builds:"

  if [ "$VERSION_STATE" = "PREPARE_FOR_SUBMISSION" ]; then
    # Current version: show most recent builds overall
    FOUND=$(echo "$BUILDS_JSON" | jq -r --argjson limit "$BUILDS_PER_VERSION" '
      sort_by(.uploaded) | reverse |
      .[:$limit][] |
      "    Build \(.build) | \(.uploaded[:10]) | \(.state)"
    ')
  else
    # Released version: find builds uploaded within 45 days before version creation
    CREATED_TS=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${created:0:19}" "+%s" 2>/dev/null || echo "0")
    WINDOW_START=$((CREATED_TS - 3888000))  # 45 days

    FOUND=$(echo "$BUILDS_JSON" | jq -r --argjson start "$WINDOW_START" --argjson end "$CREATED_TS" --argjson limit "$BUILDS_PER_VERSION" '
      [.[] |
      (.uploaded[:19] | strptime("%Y-%m-%dT%H:%M:%S") | mktime) as $ts |
      select($ts >= $start and $ts <= $end)] |
      sort_by(.uploaded) | reverse |
      .[:$limit][] |
      "    Build \(.build) | \(.uploaded[:10]) | \(.state)"
    ')
  fi

  if [ -n "$FOUND" ]; then
    echo "$FOUND"
  else
    echo "    (no builds in this window)"
  fi
done

echo ""
