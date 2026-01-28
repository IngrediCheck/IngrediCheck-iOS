---
name: asc-submit
description: Submit builds for App Store review. Use to submit for review or check submission status.
argument-hint: [status]
allowed-tools:
  - Bash(*)
---

# App Store Submission

Submit builds for App Store review and check submission status.

Arguments: $ARGUMENTS (optional: "status" to check current submission)

## Prerequisites

Validate setup first:
```bash
source .claude/skills/scripts/asc-common.sh
asc_validate || exit 1
```

## Check Submission Status

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

# Check current submission status
asc submit status --app "$ASC_APP_ID" --output table
```

## Submit for Review

### 1. Find the Build to Submit

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

# List recent builds to find the one to submit
asc builds list --app "$ASC_APP_ID" --limit 5 --output table
```

### 2. Check Build Status

```bash
# Verify build is processed and ready
asc builds info --build "BUILD_ID" | jq '{processingState: .data.attributes.processingState, version: .data.attributes.version, build: .data.attributes.buildNumber}'
```

### 3. Submit the Build

```bash
# Submit for App Store review
asc submit create --app "$ASC_APP_ID" --build "BUILD_ID"
```

## Cancel Submission

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

# Cancel an active submission
asc submit cancel --app "$ASC_APP_ID"
```

## Submission States

| State | Description |
|-------|-------------|
| `WAITING_FOR_REVIEW` | Submitted, in Apple's queue |
| `IN_REVIEW` | Currently being reviewed |
| `PENDING_DEVELOPER_RELEASE` | Approved, awaiting manual release |
| `READY_FOR_SALE` | Live on the App Store |
| `REJECTED` | Review rejected |

## Pre-Submission Checklist

Before submitting, verify:

1. **Build is valid**
   ```bash
   asc builds info --build "BUILD_ID" | jq '.data.attributes.processingState'
   # Should be "VALID"
   ```

2. **App metadata is complete**
   ```bash
   asc app-info get --app "$ASC_APP_ID" --output table
   ```

3. **Screenshots uploaded**
   ```bash
   asc assets list --version "VERSION_ID" --output table
   ```

## Subcommand Routing

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

case "${1:-status}" in
    status)
        asc submit status --app "$ASC_APP_ID" --output table
        ;;
    *)
        # Default: show status
        asc submit status --app "$ASC_APP_ID" --output table
        ;;
esac
```

## Notes

- Submissions require "App Manager" or higher API key access
- Only one submission can be active at a time
- Rejected submissions can be resubmitted after addressing issues
- Use `asc versions` to manage App Store version metadata
