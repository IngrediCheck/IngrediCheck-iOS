---
name: asc-reviews
description: Show App Store ratings and customer reviews. Use to see overall rating, user feedback, filter by stars.
argument-hint: [stars]
allowed-tools:
  - Bash(*)
---

# Ratings & Reviews

Show App Store ratings summary and customer reviews.

Arguments: $ARGUMENTS (optional star rating 1-5 to filter reviews)

## Prerequisites

Validate setup first:
```bash
source .claude/skills/scripts/asc-common.sh
asc_validate || exit 1
```

## Commands

### Show Ratings Summary

Always show ratings first using iTunes Lookup API:

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

# Fetch ratings from iTunes Lookup API (use temp file to handle control chars)
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT
curl -s "https://itunes.apple.com/lookup?id=$ASC_APP_ID&country=us" > "$TMPFILE"
AVG_RATING=$(jq -r '.results[0].averageUserRating // "N/A"' "$TMPFILE")
RATING_COUNT=$(jq -r '.results[0].userRatingCount // "N/A"' "$TMPFILE")

# Format rating with stars
if [ "$AVG_RATING" != "N/A" ] && [ "$AVG_RATING" != "null" ]; then
    STARS_DISPLAY=$(printf "%.1f" "$AVG_RATING")
else
    STARS_DISPLAY="N/A"
fi

echo "## App Store Ratings"
echo ""
echo "| Metric | Value |"
echo "|--------|-------|"
echo "| Average Rating | $STARS_DISPLAY ⭐ |"
echo "| Total Ratings | $RATING_COUNT |"
echo ""
```

### List Recent Reviews

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

# List recent reviews (newest first)
asc reviews --app "$ASC_APP_ID" --sort -createdDate --limit 10 --output table
```

### Filter by Star Rating

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

# Filter by stars (1-5)
STARS="${1:-}"
if [ -n "$STARS" ]; then
    asc reviews --app "$ASC_APP_ID" --stars "$STARS" --sort -createdDate --limit 20 --output table
else
    asc reviews --app "$ASC_APP_ID" --sort -createdDate --limit 10 --output table
fi
```

### Filter by Territory

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

# US reviews only
asc reviews --app "$ASC_APP_ID" --territory US --sort -createdDate --limit 10 --output table
```

### JSON Output (for analysis)

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

# Get all 1-star reviews for analysis
asc reviews --app "$ASC_APP_ID" --stars 1 --paginate | jq '.data[] | {rating: .attributes.rating, title: .attributes.title, body: .attributes.body, date: .attributes.createdDate}'
```

## Review Fields

Key fields in review output:
- `rating`: Star rating (1-5)
- `title`: Review title
- `body`: Review text
- `createdDate`: When review was posted
- `territory`: App Store region (US, GBR, etc.)
- `reviewerNickname`: Reviewer's display name

## Common Workflows

### Get 1-star reviews to address issues
```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config
asc reviews --app "$ASC_APP_ID" --stars 1 --sort -createdDate --limit 20 --output markdown
```

### Full Ratings & Reviews Summary (Default)

When running `/asc-reviews` without arguments, show both ratings and recent reviews:

```bash
source .claude/skills/scripts/asc-common.sh
asc_load_config

# 1. Show ratings from iTunes (use temp file to handle control chars)
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT
curl -s "https://itunes.apple.com/lookup?id=$ASC_APP_ID&country=us" > "$TMPFILE"
AVG_RATING=$(jq -r '.results[0].averageUserRating // "N/A"' "$TMPFILE")
RATING_COUNT=$(jq -r '.results[0].userRatingCount // "N/A"' "$TMPFILE")

if [ "$AVG_RATING" != "N/A" ] && [ "$AVG_RATING" != "null" ]; then
    STARS_DISPLAY=$(printf "%.1f" "$AVG_RATING")
else
    STARS_DISPLAY="N/A"
fi

echo "## App Store Ratings"
echo ""
echo "| Metric | Value |"
echo "|--------|-------|"
echo "| Average Rating | $STARS_DISPLAY ⭐ |"
echo "| Total Ratings | $RATING_COUNT |"
echo ""

# 2. Show recent reviews
echo "## Recent Reviews"
echo ""
asc reviews --app "$ASC_APP_ID" --sort -createdDate --limit 10 --output markdown
```

### Respond to a review
```bash
# Get review ID from list, then:
asc reviews respond --review-id "REVIEW_ID" --response "Thank you for your feedback..."
```

## Responding to Reviews

```bash
# Respond to a customer review
asc reviews respond --review-id "REVIEW_ID" --response "Thank you for your feedback! We're working on..."

# Get existing response
asc reviews response for-review --review-id "REVIEW_ID"

# Delete a response
asc reviews response delete --id "RESPONSE_ID" --confirm
```
