---
name: asc-sales
description: Download sales reports and analytics from App Store Connect.
argument-hint: [date YYYY-MM-DD]
allowed-tools:
  - Bash(*)
---

# Sales & Analytics

Download sales reports and analytics from App Store Connect.

Arguments: $ARGUMENTS (optional: date in YYYY-MM-DD format)

## Prerequisites

Validate setup first:
```bash
source .claude/skills/scripts/asc-common.sh
asc_validate || exit 1
```

**Note**: Sales reports require a Vendor Number. Find it in App Store Connect under "Payments and Financial Reports".

## Daily Sales Summary

```bash
# Get yesterday's sales (daily reports have ~1 day delay)
DATE="${1:-$(date -v-1d +%Y-%m-%d)}"
asc analytics sales \
    --vendor "$ASC_VENDOR_NUMBER" \
    --type SALES \
    --subtype SUMMARY \
    --frequency DAILY \
    --date "$DATE" \
    --decompress
```

## Monthly Sales Summary

```bash
# Get last month's sales
MONTH=$(date -v-1m +%Y-%m)
asc analytics sales \
    --vendor "$ASC_VENDOR_NUMBER" \
    --type SALES \
    --subtype SUMMARY \
    --frequency MONTHLY \
    --date "$MONTH" \
    --decompress
```

## Subscription Reports

```bash
# Detailed subscription report for a month
asc analytics sales \
    --vendor "$ASC_VENDOR_NUMBER" \
    --type SUBSCRIPTION \
    --subtype DETAILED \
    --frequency MONTHLY \
    --date "2025-01" \
    --decompress
```

## Financial Reports

```bash
# Download financial report for a region
asc finance reports \
    --vendor "$ASC_VENDOR_NUMBER" \
    --report-type FINANCIAL \
    --region "US" \
    --date "2025-01"
```

### List Available Regions

```bash
asc finance regions --output table
```

## App Analytics (Advanced)

For detailed app analytics (downloads, impressions, etc.):

### Create Analytics Request

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

# Request ongoing analytics access
asc analytics request --app "$ASC_APP_ID" --access-type ONGOING
```

### List Analytics Requests

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

asc analytics requests --app "$ASC_APP_ID" --output table
```

### Download Analytics Data

```bash
# Get reports for a request
asc analytics get --request-id "REQUEST_ID"

# Download specific report instance
asc analytics download --request-id "REQUEST_ID" --instance-id "INSTANCE_ID"
```

## Report Types

| Type | Description |
|------|-------------|
| `SALES` | App sales and downloads |
| `PRE_ORDER` | Pre-order metrics |
| `NEWSSTAND` | Newsstand subscriptions |
| `SUBSCRIPTION` | In-app subscriptions |
| `SUBSCRIPTION_EVENT` | Subscription events (cancellations, etc.) |

## Subtypes

| Subtype | Description |
|---------|-------------|
| `SUMMARY` | Aggregated summary data |
| `DETAILED` | Line-by-line transaction data |

## Configuration

Add vendor number to `.asc/config.json`:

```json
{
  "app_id": "YOUR_APP_ID",
  "profile": "IngrediCheck",
  "vendor_number": "YOUR_VENDOR_NUMBER"
}
```

Or set environment variable:
```bash
export ASC_VENDOR_NUMBER="YOUR_VENDOR_NUMBER"
```

## Notes

- Daily reports have ~1 day delay
- Monthly reports available after month ends
- Financial reports require Account Holder, Admin, or Finance role
- Large reports are gzip compressed (use `--decompress` to extract)
