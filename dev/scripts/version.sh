#!/bin/bash

# Znuny Development Environment - Version display and check
# Used by znuny-dev.sh for 'zd version' and for first-start-of-day check

set -e

if [ -z "${ZNUNY_DEV_DIR:-}" ]; then
    ZNUNY_DEV_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
fi

# Resolve script dir so it works when this file is sourced (use BASH_SOURCE) or run directly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# Load common functions and env when script is run standalone
if [ -z "${print_header:-}" ]; then
    # shellcheck source=common.sh
    source "$SCRIPT_DIR/common.sh"
    load_environment
fi

# Outputs version check result (one line: success or warning). Returns 0 if up to date, 1 if update available.
# Uses: ZNUNY_DEV_DIR, BUILD_COMMIT (from RELEASE), current_version (from RELEASE).
# Caller must ensure RELEASE is sourced when BUILD_COMMIT is needed.
print_version_check_result() {
    local release_file="${1:-$ZNUNY_DEV_DIR/RELEASE}"
    local current_version=""
    local latest_version="undef"
    local latest_commit="undef"
    local get_latest_result
    local higher

    if [ -f "$release_file" ]; then
        # shellcheck source=../../RELEASE
        source "$release_file"
        current_version="${VERSION:-1.0.0}"
    else
        current_version="1.0.0"
    fi

    get_latest_result=$(get_latest_version --path "$ZNUNY_DEV_DIR" 2>/dev/null)
    if [ -n "$get_latest_result" ]; then
        latest_version=$(echo "$get_latest_result" | sed -n '1p')
        latest_commit=$(echo "$get_latest_result" | sed -n '2p')
    fi

    if [ "$latest_version" != "undef" ]; then
        higher=$(printf '%s\n%s\n' "$current_version" "$latest_version" | sort -V 2>/dev/null | tail -1)
        if [ "$current_version" = "$latest_version" ]; then
            print_success "Up to date (latest: $latest_version)"
            return 0
        elif [ "$higher" = "$latest_version" ]; then
            print_warning "New version available: $latest_version (current: $current_version)"
            return 1
        else
            print_success "Up to date (latest: $latest_version)"
            return 0
        fi
    elif [ "$latest_commit" != "undef" ] && [ -n "${BUILD_COMMIT:-}" ]; then
        if [ "${BUILD_COMMIT:0:7}" = "$latest_commit" ] || [ "$BUILD_COMMIT" = "$latest_commit" ]; then
            print_success "Up to date with remote (commit: $latest_commit)"
            return 0
        else
            print_warning "Remote has different commit: $latest_commit (current: ${BUILD_COMMIT:0:7})"
            return 1
        fi
    fi
    return 0
}

# Docker version: header and table (Docker, Docker Compose).
show_docker_version() {
    echo ""
    print_header "Docker Environment"

    print_table "Docker Version" "$(docker --version 2>/dev/null || echo 'Not installed')"
    local compose_cmd
    compose_cmd=$(get_compose_cmd 2>/dev/null) || compose_cmd="docker compose"
    print_table "Docker Compose Version" "$($compose_cmd version --short 2>/dev/null || $compose_cmd --version 2>/dev/null || echo 'Not installed')"
}

# Version Check: header, latest version/commit table, and result (success/warning line).
show_zd_version() {
    local release_file="$ZNUNY_DEV_DIR/RELEASE"

    echo ""
    print_header "Version Check"

    local get_latest_result
    get_latest_result=$(get_latest_version --path "$ZNUNY_DEV_DIR" 2>/dev/null)
    local latest_version="undef"
    local latest_commit="undef"
    if [ -n "$get_latest_result" ]; then
        latest_version=$(echo "$get_latest_result" | sed -n '1p')
        latest_commit=$(echo "$get_latest_result" | sed -n '2p')
    fi
    print_table "Latest version (remote)" "${latest_version}"
    print_table "Latest commit (remote)" "${latest_commit}"
    echo ""

    print_version_check_result "$release_file" || true
}

# Full version display (Znuny Dev, Docker, version check).
show_versions() {
    local release_file="$ZNUNY_DEV_DIR/RELEASE"
    local current_version=""

    print_header "Znuny Development Environment"

    if [ -f "$release_file" ]; then
        # shellcheck source=../../RELEASE
        source "$release_file"
        current_version="${VERSION:-1.0.0}"
        print_table "Version" "$current_version"
        print_table "Build Date" "${BUILD_DATE:-Unknown}"
        print_table "Build Commit" "${BUILD_COMMIT:-Unknown}"
        print_table "Build Branch" "${BUILD_BRANCH:-Unknown}"
    else
        current_version="1.0.0"
        print_table "Version" "$current_version"
        print_table "Build Date" "Unknown"
        print_table "Build Commit" "Unknown"
        print_table "Build Branch" "Unknown"
    fi

    show_docker_version

    show_zd_version
}

# Always run on zd start; exit immediately if ZD_LAST_VERSION_CHECK_DATE is already today.
# Otherwise run version check, show message if update available, then update ZD_LAST_VERSION_CHECK_DATE in .env.
check_version() {
    local env_file="$ZNUNY_DEV_DIR/.env"

    if [ ! -f "$env_file" ]; then
        return 0
    fi

    local today
    today=$(date +%Y-%m-%d)
    local last_check
    last_check=$(grep -E '^ZD_LAST_VERSION_CHECK_DATE=' "$env_file" 2>/dev/null | cut -d= -f2- || true)

    if [ "$last_check" = "$today" ]; then
        return 0
    fi

    print_header "Checking for new version"
    print_header "========================"
    echo ""
    print_table "Last version check" "$last_check"
    print_table "Today" "$today"

    # Same file as ../../.env when ZNUNY_DEV_DIR is repo root; often missing in CI (SC1091).
    # shellcheck source=../../.env
    # shellcheck disable=SC1091
    source "$env_file" 2>/dev/null || true

    local release_file="$ZNUNY_DEV_DIR/RELEASE"
    if [ -f "$release_file" ]; then
        # shellcheck source=../../RELEASE
        source "$release_file"
    fi

    local output
    output=$(show_zd_version 2>&1) || true

    if echo "$output" | grep -q "New version available\|different commit"; then
        echo "$output"
        print_status "New version available, please run 'git pull' and 'zd version' to check for updates."
        echo ""
    fi

    if [ -f "$SCRIPT_DIR/env.sh" ]; then
        "$SCRIPT_DIR/env.sh" --set-var ZD_LAST_VERSION_CHECK_DATE "$today" >/dev/null 2>/dev/null || true
    fi
    return 0
}
