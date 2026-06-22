#!/usr/bin/env bash
# Emit znuny-dev instance status as JSON (one line) for the dev dashboard.
# Can be run on the host or inside the dashboard container.
# Usage: status-json.sh [--verbose|-v] [framework|all]
set -euo pipefail

# Resolve repo root from this script (must stay valid inside Docker when .env overrides ZNUNY_DEV_DIR).
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "${_SCRIPT_DIR}/../../.." && pwd)"

realign_znuny_paths() {
    export ZNUNY_DEV_DIR="$REPO_ROOT"
    export INSTANCES_DIR="$ZNUNY_DEV_DIR/instances"
    cd "$ZNUNY_DEV_DIR" || exit 1
}

realign_znuny_paths

# shellcheck source=dev/scripts/common.sh
source "$ZNUNY_DEV_DIR/dev/scripts/common.sh"
load_environment
set_zd_cmd
export ZD_CMD
# .env may set ZNUNY_DEV_DIR / INSTANCES_DIR to host paths (not valid inside the dashboard container).
realign_znuny_paths

# get_compose_file (used by get_external_db_port → database_url in JSON); same order as instance.sh
# shellcheck source=dev/scripts/instance/compose.sh
source "$ZNUNY_DEV_DIR/dev/scripts/instance/compose.sh"
realign_znuny_paths

# shellcheck source=dev/scripts/instance/network.sh
source "$ZNUNY_DEV_DIR/dev/scripts/instance/network.sh"
realign_znuny_paths

# shellcheck source=dev/scripts/instance/status.sh
source "$ZNUNY_DEV_DIR/dev/scripts/instance/status.sh"

VERBOSE_MODE=false
FRAMEWORK=""

while [[ $# -gt 0 ]]; do
    case $1 in
    --verbose | -v)
        VERBOSE_MODE=true
        shift
        ;;
    *)
        if [ -n "$FRAMEWORK" ]; then
            print_error "Unexpected argument: $1"
            exit 1
        fi
        FRAMEWORK="$1"
        shift
        ;;
    esac
done

if [ "$FRAMEWORK" = "all" ]; then
    FRAMEWORK=""
fi

emit_status_json_collection "$FRAMEWORK" "$VERBOSE_MODE"
