#!/bin/bash
# Reddit API helper functions for mk-reply-guy skill
# Source this file: source "$(dirname "$0")/../scripts/reddit-api.sh"
#
# Each public function is self-contained: loads config, gets token, makes request.
# This is intentional — Bash state doesn't persist between Claude tool calls.

# Find repo root (git rev-parse works from any subdirectory)
REDDIT_CONFIG_FILE="$(git rev-parse --show-toplevel 2>/dev/null)/.env"
REDDIT_TOKEN_URL="https://www.reddit.com/api/v1/access_token"
REDDIT_API_BASE="https://oauth.reddit.com"

# --- Internal helpers (not meant to be called directly) ---

_reddit_log()   { echo "[reddit-api] $1"; }
_reddit_error() { echo "[reddit-api] ERROR: $1" >&2; }

# Load and validate credentials from config file.
# Sets: REDDIT_CLIENT_ID, REDDIT_CLIENT_SECRET, REDDIT_USERNAME, REDDIT_PASSWORD, REDDIT_USER_AGENT
reddit_load_config() {
    if [ ! -f "$REDDIT_CONFIG_FILE" ]; then
        _reddit_error "Credentials file not found: $REDDIT_CONFIG_FILE"
        echo ""
        echo "Create a .env file in the repo root with:"
        echo "  REDDIT_CLIENT_ID=..."
        echo "  REDDIT_CLIENT_SECRET=..."
        echo "  REDDIT_USERNAME=..."
        echo "  REDDIT_PASSWORD=..."
        echo "  REDDIT_USER_AGENT=IngrediCheck-ReplyGuy/1.0 by /u/YourUsername"
        return 1
    fi

    # shellcheck disable=SC1090
    source "$REDDIT_CONFIG_FILE"

    # Validate required vars
    local missing=()
    [ -z "$REDDIT_CLIENT_ID" ] && missing+=("REDDIT_CLIENT_ID")
    [ -z "$REDDIT_CLIENT_SECRET" ] && missing+=("REDDIT_CLIENT_SECRET")
    [ -z "$REDDIT_USERNAME" ] && missing+=("REDDIT_USERNAME")
    [ -z "$REDDIT_PASSWORD" ] && missing+=("REDDIT_PASSWORD")
    [ -z "$REDDIT_USER_AGENT" ] && missing+=("REDDIT_USER_AGENT")

    if [ ${#missing[@]} -gt 0 ]; then
        _reddit_error "Missing required variables in $REDDIT_CONFIG_FILE: ${missing[*]}"
        return 1
    fi

    return 0
}

# Get OAuth2 access token via password grant.
# Optional arg: OTP code for 2FA accounts.
# Prints the access token to stdout. Returns 1 on failure.
reddit_get_token() {
    local otp="$1"

    local otp_args=()
    if [ -n "$otp" ]; then
        otp_args=(-H "x-reddit-otp: $otp")
    fi

    local response
    response=$(curl -s -X POST "$REDDIT_TOKEN_URL" \
        -u "${REDDIT_CLIENT_ID}:${REDDIT_CLIENT_SECRET}" \
        -A "$REDDIT_USER_AGENT" \
        "${otp_args[@]}" \
        --data-urlencode "grant_type=password" \
        --data-urlencode "username=${REDDIT_USERNAME}" \
        --data-urlencode "password=${REDDIT_PASSWORD}" \
        --data-urlencode "scope=identity,read,submit" \
        2>/dev/null)

    local token
    token=$(echo "$response" | jq -r '.access_token // empty' 2>/dev/null)

    if [ -z "$token" ]; then
        local error_msg
        error_msg=$(echo "$response" | jq -r '.error // .message // "unknown error"' 2>/dev/null)
        _reddit_error "Failed to get token: $error_msg"
        return 1
    fi

    echo "$token"
    return 0
}

# Generic Reddit API wrapper.
# Usage: reddit_api METHOD ENDPOINT [--data-urlencode key=value ...]
# METHOD: GET or POST
# ENDPOINT: e.g. /r/Celiac/search or /api/comment (no base URL)
#
# All extra args are passed as --data-urlencode params to curl.
# For GET, params are appended to URL via -G. For POST, they go in the body.
#
# This function is self-contained: loads config, gets token, makes the request.
# Optional: set REDDIT_OTP env var before calling if 2FA is needed.
reddit_api() {
    local method="$1"
    shift
    local endpoint="$1"
    shift
    # Remaining args are --data-urlencode pairs

    reddit_load_config || return 1

    local token
    token=$(reddit_get_token "$REDDIT_OTP") || return 1

    local url="${REDDIT_API_BASE}${endpoint}"

    local curl_args=(
        -s
        -X "$method"
        -H "Authorization: Bearer $token"
        -A "$REDDIT_USER_AGENT"
    )

    # For GET requests, use -G so --data-urlencode params become query string
    if [ "$method" = "GET" ]; then
        curl_args+=(-G)
    fi

    # Append all --data-urlencode args
    while [ $# -gt 0 ]; do
        curl_args+=("$1")
        shift
    done

    local response http_code
    response=$(curl "${curl_args[@]}" -w "\n%{http_code}" "$url" 2>/dev/null)
    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | sed '$d')

    # Handle rate limiting
    if [ "$http_code" = "429" ]; then
        _reddit_error "Rate limited (429). Wait and retry."
        echo "$response"
        return 1
    fi

    # Handle auth failure
    if [ "$http_code" = "401" ]; then
        _reddit_error "Unauthorized (401). Token may be expired or credentials invalid."
        echo "$response"
        return 1
    fi

    # Handle other errors
    if [ "${http_code:0:1}" != "2" ]; then
        _reddit_error "HTTP $http_code from $method $endpoint"
        echo "$response"
        return 1
    fi

    echo "$response"
    return 0
}
