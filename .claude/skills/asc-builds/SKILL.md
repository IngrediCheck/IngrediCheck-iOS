---
name: asc-builds
description: List builds from App Store Connect. Use to check build status, versions, and upload dates.
argument-hint: [all|NUM]
allowed-tools:
  - Bash(*)
---

# List Builds

List recent builds from App Store Connect, grouped by marketing version.

Arguments: $ARGUMENTS
- (none): Show last 2 marketing versions with 3 builds each
- `all`: Show flat list of recent builds
- `NUM`: Show last NUM builds (flat list)

## Default: Builds by Marketing Version

```bash
.claude/skills/asc-builds/scripts/list-by-version.sh 2 3
```

This shows:
- Last 2 marketing versions
- 3 most recent builds for each version
- Which build was submitted to the App Store

## Flat List of All Builds

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc builds list --app "$ASC_APP_ID" --limit 10 --output table
```

## Latest Build Only

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc builds latest --app "$ASC_APP_ID" --output table
```

## Build Details

```bash
# Get details for a specific build
asc builds info --build "BUILD_ID" --pretty
```

## Build Fields

Key fields in build output:
- `version`: Build number (CFBundleVersion)
- `uploadedDate`: When uploaded to App Store Connect
- `processingState`: PROCESSING, VALID, INVALID
- `expirationDate`: When TestFlight build expires

## Argument Routing

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

ARG="${1:-}"

if [ -z "$ARG" ]; then
  # Default: grouped by marketing version
  .claude/skills/asc-builds/scripts/list-by-version.sh 2 3
elif [ "$ARG" = "all" ]; then
  # Flat list
  asc builds list --app "$ASC_APP_ID" --limit 15 --output table
elif [[ "$ARG" =~ ^[0-9]+$ ]]; then
  # Specific limit
  asc builds list --app "$ASC_APP_ID" --limit "$ARG" --output table
else
  echo "Usage: /asc-builds [all|NUM]"
  echo "  (none) - Last 2 versions with 3 builds each"
  echo "  all    - Flat list of recent builds"
  echo "  NUM    - Last NUM builds"
fi
```
