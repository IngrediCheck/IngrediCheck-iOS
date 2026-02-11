---
name: asc-testflight
description: Manage TestFlight beta testers, groups, feedback, and crashes. Use for beta testing workflows.
argument-hint: [testers|groups|feedback|crashes]
allowed-tools:
  - Bash(*)
---

# TestFlight Management

Manage TestFlight beta testers, groups, feedback, and crash reports.

Arguments: $ARGUMENTS (optional: testers, groups, feedback, crashes)

## Prerequisites

Validate setup first:
```bash
source .claude/skills/scripts/asc-common.sh
asc_validate || exit 1
```

## Overview Command

Show TestFlight summary:
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

echo "=== Beta Groups ==="
asc beta-groups list --app "$ASC_APP_ID" --output table

echo ""
echo "=== Recent Feedback ==="
asc feedback --app "$ASC_APP_ID" --limit 5 --sort -createdDate --output table

echo ""
echo "=== Recent Crashes ==="
asc crashes --app "$ASC_APP_ID" --limit 5 --sort -createdDate --output table
```

## Beta Testers

### List Testers
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc beta-testers list --app "$ASC_APP_ID" --output table
```

### Add Tester
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
# Add tester to app (optionally specify group)
asc beta-testers add --app "$ASC_APP_ID" --email "tester@example.com" --group "Beta Testers"
```

### Invite Tester
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc beta-testers invite --app "$ASC_APP_ID" --email "tester@example.com"
```

### Remove Tester
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc beta-testers remove --app "$ASC_APP_ID" --email "tester@example.com"
```

## Beta Groups

### List Groups
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc beta-groups list --app "$ASC_APP_ID" --output table
```

### Create Group
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc beta-groups create --app "$ASC_APP_ID" --name "Internal Testers"
```

### Add Build to Group
```bash
# Enable build for a beta group
asc builds add-groups --build "BUILD_ID" --group "GROUP_ID"
```

## Feedback

### List Recent Feedback
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc feedback --app "$ASC_APP_ID" --sort -createdDate --limit 20 --output table
```

### Feedback with Screenshots
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc feedback --app "$ASC_APP_ID" --include-screenshots --limit 10
```

### Filter by Device
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc feedback --app "$ASC_APP_ID" --device-model "iPhone15,3" --output table
```

## Crash Reports

### List Recent Crashes
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc crashes --app "$ASC_APP_ID" --sort -createdDate --limit 20 --output table
```

### Export Crashes (JSON)
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc crashes --app "$ASC_APP_ID" --paginate > crashes.json
```

### Filter by OS Version
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc crashes --app "$ASC_APP_ID" --os-version "18.0" --output table
```

## Subcommand Routing

Based on argument ($ARGUMENTS), run the appropriate section:

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

case "${1:-overview}" in
    testers)
        asc beta-testers list --app "$ASC_APP_ID" --output table
        ;;
    groups)
        asc beta-groups list --app "$ASC_APP_ID" --output table
        ;;
    feedback)
        asc feedback --app "$ASC_APP_ID" --sort -createdDate --limit 20 --output table
        ;;
    crashes)
        asc crashes --app "$ASC_APP_ID" --sort -createdDate --limit 20 --output table
        ;;
    *)
        # Overview
        echo "=== Beta Groups ==="
        asc beta-groups list --app "$ASC_APP_ID" --output table
        echo ""
        echo "=== Beta Testers (first 10) ==="
        asc beta-testers list --app "$ASC_APP_ID" --limit 10 --output table
        ;;
esac
```
