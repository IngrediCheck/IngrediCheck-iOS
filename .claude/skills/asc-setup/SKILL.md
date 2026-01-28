---
name: asc-setup
description: Setup and validate App Store Connect CLI. Use when user needs to configure asc authentication or check setup status.
allowed-tools:
  - Bash(*)
---

# App Store Connect Setup

Validate installation and configure authentication for the `asc` CLI.

## Quick Check

```bash
# Check if asc is installed
asc --version

# Check authentication status
asc auth status
```

## Setup Steps

### 1. Install asc (if needed)

```bash
brew tap rudrankriyam/tap
brew install rudrankriyam/tap/asc
```

### 2. Create API Key

If not authenticated, guide the user to create an API key:

1. Open: https://appstoreconnect.apple.com/access/integrations/api
2. Click "+" to create a new key
3. Name: "Claude Code" (or similar)
4. Access: "App Manager" (or higher for submissions)
5. Download the `.p8` file (only available once!)
6. Note the **Key ID** and **Issuer ID**

### 3. Authenticate

```bash
asc auth login \
  --name "IngrediCheck" \
  --key-id "<KEY_ID>" \
  --issuer-id "<ISSUER_ID>" \
  --private-key /path/to/AuthKey_XXXXX.p8
```

### 4. Find App ID

```bash
# List all apps (table format for readability)
asc apps --output table

# Or search by bundle ID
asc apps --bundle-id "llc.fungee.ingredicheck" --output table
```

### 5. Save Config

Create `.asc/config.json` with the discovered app ID:

```bash
mkdir -p .asc
cat > .asc/config.json << 'EOF'
{
  "app_id": "DISCOVERED_APP_ID",
  "profile": "IngrediCheck"
}
EOF
```

## IngrediCheck App Details

| Property | Value |
|----------|-------|
| Bundle ID | `llc.fungee.ingredicheck` |
| Team ID | `58MYNHGN72` |
| Scheme | `IngrediCheck` |
| Project | `IngrediCheck.xcodeproj` |

## Verification

After setup, verify everything works:

```bash
# Should show authenticated profile
asc auth status

# Should list the app
asc apps --bundle-id "llc.fungee.ingredicheck" --output table

# Test builds access (requires app ID)
source .claude/skills/scripts/asc-common.sh
asc_load_config && asc builds list --app "$ASC_APP_ID" --limit 1
```

## Troubleshooting

- **"No credentials stored"**: Run `asc auth login` with your API key
- **"Invalid key"**: Verify key ID, issuer ID, and .p8 file path
- **"Forbidden"**: API key may lack required permissions
- **App not found**: Double-check bundle ID or use `asc apps` to list all apps
