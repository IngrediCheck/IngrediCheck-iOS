---
name: asc-builds
description: List builds from App Store Connect. Use to check build status, versions, and upload dates.
argument-hint: [all|NUM]
allowed-tools:
  - Task
---

# List Builds

List recent builds from App Store Connect, grouped by marketing version.

Arguments: $ARGUMENTS
- (none): Show last 2 marketing versions with 3 builds each
- `all`: Show flat list of recent builds
- `NUM`: Show last NUM builds (flat list)

## IMPORTANT: Run via Background Agent

To avoid polluting context with intermediate API calls, ALWAYS use a Task agent to run the build script.

Use the Task tool with:
- `subagent_type`: `Bash`
- `prompt`: The appropriate bash command based on arguments

### Default (no arguments)

Spawn a Bash agent with this prompt:
```
Run this command and return ONLY the table output, no other commentary:
.claude/skills/asc-builds/scripts/list-by-version.sh 2 3
```

### With "all" argument

Spawn a Bash agent with this prompt:
```
Run these commands and return ONLY the table output:
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc builds list --app "$ASC_APP_ID" --limit 15 --output table
```

### With numeric argument (e.g., "10")

Spawn a Bash agent with this prompt:
```
Run these commands and return ONLY the table output:
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc builds list --app "$ASC_APP_ID" --limit NUM --output table
```
(Replace NUM with the actual number)

## Output Format

The agent will return a table like:
```
Version | Build        | Uploaded   | External
--------|--------------|------------|------------------
2.0     | 14           | 2026-01-27 | IN_BETA_TESTING
2.0     | 13           | 2026-01-23 | IN_BETA_TESTING
1.5.0   | 11           | 2025-12-18 | IN_BETA_TESTING
```

Present this to the user as a formatted markdown table with status icons:
- ✅ IN_BETA_TESTING
- ⛔ EXPIRED
- ⏸️ READY_FOR_BETA_SUBMISSION
