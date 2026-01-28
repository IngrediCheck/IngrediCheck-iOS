---
name: asc-builds
description: List builds from App Store Connect. Use to check build status, versions, and upload dates.
argument-hint: [limit]
allowed-tools:
  - Bash(*)
---

# List Builds

List recent builds from App Store Connect.

Arguments: $ARGUMENTS (optional limit, default 10)

## Prerequisites

Validate setup first:
```bash
source .claude/skills/scripts/asc-common.sh
asc_validate || exit 1
```

## Commands

### List Recent Builds

```bash
# Load app ID from config
source .claude/skills/scripts/asc-common.sh
asc_load_config

# List builds (default limit 10, adjust with argument)
LIMIT="${1:-10}"
asc builds list --app "$ASC_APP_ID" --limit "$LIMIT" --output table
```

### Latest Build Only

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc builds latest --app "$ASC_APP_ID" --output table
```

### Build Details

```bash
# Get details for a specific build
asc builds info --build "BUILD_ID" --output table
```

### JSON Output (for parsing)

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc builds list --app "$ASC_APP_ID" --limit 5
```

## Build Fields

Key fields in build output:
- `version`: Marketing version (e.g., 1.2.0)
- `buildNumber`: Build number (e.g., 42)
- `uploadedDate`: When uploaded to App Store Connect
- `processingState`: PROCESSING, VALID, INVALID
- `betaReviewStatus`: WAITING_FOR_BETA_REVIEW, IN_BETA_REVIEW, APPROVED

## Common Workflows

### Check if latest build is ready for TestFlight
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc builds latest --app "$ASC_APP_ID" | jq '{version: .data.attributes.version, build: .data.attributes.buildNumber, state: .data.attributes.processingState}'
```

### List builds awaiting beta review
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc builds list --app "$ASC_APP_ID" --paginate | jq '.data[] | select(.attributes.betaReviewStatus == "WAITING_FOR_BETA_REVIEW")'
```
