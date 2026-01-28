#!/bin/bash
# Shared helper functions for asc-* skills
# Source this file: source "$(dirname "$0")/../scripts/asc-common.sh"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
asc_log() { echo -e "${GREEN}[ASC]${NC} $1"; }
asc_warn() { echo -e "${YELLOW}[ASC]${NC} $1"; }
asc_error() { echo -e "${RED}[ASC]${NC} $1"; }
asc_info() { echo -e "${BLUE}[ASC]${NC} $1"; }

# Check if asc is installed
asc_check_install() {
    if ! command -v asc &>/dev/null; then
        asc_error "asc CLI not installed!"
        echo ""
        echo "Install with:"
        echo "  brew tap rudrankriyam/tap"
        echo "  brew install rudrankriyam/tap/asc"
        return 1
    fi
    return 0
}

# Check if authenticated
asc_check_auth() {
    local auth_status
    auth_status=$(asc auth status 2>&1)
    if echo "$auth_status" | grep -q "No credentials"; then
        asc_error "Not authenticated!"
        echo ""
        echo "Run /asc-setup to configure authentication"
        return 1
    fi
    return 0
}

# Get app ID from config or environment
asc_get_app_id() {
    # Priority: 1) Argument, 2) Config file, 3) Environment
    if [ -n "$1" ]; then
        echo "$1"
        return 0
    fi

    local config_file=".asc/config.json"
    if [ -f "$config_file" ]; then
        local app_id
        app_id=$(jq -r '.app_id // empty' "$config_file" 2>/dev/null)
        if [ -n "$app_id" ]; then
            echo "$app_id"
            return 0
        fi
    fi

    if [ -n "$ASC_APP_ID" ]; then
        echo "$ASC_APP_ID"
        return 0
    fi

    asc_error "No app ID configured!"
    echo ""
    echo "Run /asc-setup to discover and configure your app ID"
    return 1
}

# Load config and set ASC_APP_ID and ASC_VENDOR_NUMBER
asc_load_config() {
    local app_id
    app_id=$(asc_get_app_id "$1") || return 1
    export ASC_APP_ID="$app_id"

    # Also load vendor number if available
    local config_file=".asc/config.json"
    if [ -f "$config_file" ]; then
        local vendor_number
        vendor_number=$(jq -r '.vendor_number // empty' "$config_file" 2>/dev/null)
        if [ -n "$vendor_number" ]; then
            export ASC_VENDOR_NUMBER="$vendor_number"
        fi
    fi
    return 0
}

# Validate everything is ready
asc_validate() {
    asc_check_install || return 1
    asc_check_auth || return 1
    asc_load_config "$1" || return 1
    return 0
}

# Format JSON output nicely for display (optional pretty print)
asc_format_json() {
    if [ "$1" = "--pretty" ]; then
        jq '.'
    else
        cat
    fi
}

# Get current profile name
asc_get_profile() {
    local config_file=".asc/config.json"
    if [ -f "$config_file" ]; then
        jq -r '.profile // "default"' "$config_file" 2>/dev/null
    else
        echo "default"
    fi
}
