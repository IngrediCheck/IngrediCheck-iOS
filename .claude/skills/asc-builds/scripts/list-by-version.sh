#!/bin/bash
# List builds grouped by marketing version with TestFlight status
# Usage: ./list-by-version.sh [num_versions] [builds_per_version]
# Optimized: parallel beta-details queries, minimal API calls

set -e

source "$(dirname "$0")/../../scripts/asc-common.sh"
asc_load_config

NUM_VERSIONS="${1:-2}"
BUILDS_PER_VERSION="${2:-3}"

# Create temp dir for parallel results
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# === PHASE 1: Fetch all data upfront (2 API calls only) ===
VERSIONS_JSON=$(asc versions list --app "$ASC_APP_ID")
BUILDS_JSON=$(asc builds list --app "$ASC_APP_ID" --limit 50)

# === PHASE 2: Process versions and determine builds (no API calls) ===
echo "$VERSIONS_JSON" | jq -r ".data[:$NUM_VERSIONS][] | \"\(.id)|\(.attributes.versionString)|\(.attributes.createdDate)|\(.attributes.appStoreState)\"" > "$TMPDIR/versions.txt"

while IFS='|' read vid ver created state; do
  CREATED_TS=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${created:0:19}" "+%s" 2>/dev/null || echo "0")

  if [ "$state" = "PREPARE_FOR_SUBMISSION" ]; then
    # Current version: most recent builds
    echo "$BUILDS_JSON" | jq -r --argjson limit "$BUILDS_PER_VERSION" \
      '.data[:$limit][] | "\(.id)|\(.attributes.version)|\(.attributes.uploadedDate[:10])"' \
      > "$TMPDIR/builds_${ver}.txt"
  else
    # Released version: builds from 45 days before creation
    WINDOW_START=$((CREATED_TS - 3888000))
    echo "$BUILDS_JSON" | jq -r --argjson start "$WINDOW_START" --argjson end "$CREATED_TS" --argjson limit "$BUILDS_PER_VERSION" '
      [.data[] |
      (.attributes.uploadedDate[:19] | strptime("%Y-%m-%dT%H:%M:%S") | mktime) as $ts |
      select($ts >= $start and $ts <= $end)] |
      sort_by(.attributes.uploadedDate) | reverse |
      .[:$limit][] |
      "\(.id)|\(.attributes.version)|\(.attributes.uploadedDate[:10])"
    ' > "$TMPDIR/builds_${ver}.txt"
  fi

  echo "$ver" >> "$TMPDIR/version_order.txt"
done < "$TMPDIR/versions.txt"

# === PHASE 3: Fetch beta details in PARALLEL ===
cat "$TMPDIR"/builds_*.txt 2>/dev/null | cut -d'|' -f1 | sort -u > "$TMPDIR/all_build_ids.txt"

# Query beta details in parallel (up to 6 concurrent)
while read build_id; do
  [ -z "$build_id" ] && continue
  (
    beta=$(asc testflight beta-details get --build "$build_id" 2>/dev/null)
    external=$(echo "$beta" | jq -r '.data[0].attributes.externalBuildState // "N/A"')
    echo "$external" > "$TMPDIR/beta_${build_id}.txt"
  ) &

  # Limit parallelism to 6
  while [ $(jobs -r | wc -l) -ge 6 ]; do
    sleep 0.05
  done
done < "$TMPDIR/all_build_ids.txt"

wait

# === PHASE 4: Output results ===
echo "Version | Build        | Uploaded   | External"
echo "--------|--------------|------------|------------------"

while read ver; do
  [ -z "$ver" ] && continue
  [ -f "$TMPDIR/builds_${ver}.txt" ] || continue
  while IFS='|' read id build date; do
    external="N/A"
    [ -f "$TMPDIR/beta_${id}.txt" ] && external=$(cat "$TMPDIR/beta_${id}.txt")
    printf "%-7s | %-12s | %s | %s\n" "$ver" "$build" "$date" "$external"
  done < "$TMPDIR/builds_${ver}.txt"
done < "$TMPDIR/version_order.txt"
