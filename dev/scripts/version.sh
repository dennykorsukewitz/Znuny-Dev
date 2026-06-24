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

# Short hash of the current git checkout (not RELEASE BUILD_COMMIT).
get_checkout_commit() {
    local dir="${1:-$ZNUNY_DEV_DIR}"
    git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo ""
}

# Compare two commit refs (full or short hashes).
commits_equal() {
    local a="$1"
    local b="$2"

    if [ -z "$a" ] || [ -z "$b" ]; then
        return 1
    fi
    if [ "$a" = "$b" ]; then
        return 0
    fi
    if [ "${a:0:7}" = "${b:0:7}" ]; then
        return 0
    fi
    if [ "${a:0:7}" = "$b" ] || [ "$a" = "${b:0:7}" ]; then
        return 0
    fi
    return 1
}

# Outputs version check result (one line: success or warning). Returns 0 if up to date, 1 if update available.
# Compares remote HEAD to local git checkout. BUILD_COMMIT (RELEASE) is informational only.
print_version_check_result() {
    local release_file="${1:-$ZNUNY_DEV_DIR/RELEASE}"
    local current_version=""
    local latest_version="undef"
    local latest_commit="undef"
    local get_latest_result
    local higher
    local checkout_commit

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
    elif [ "$latest_commit" != "undef" ]; then
        checkout_commit=$(get_checkout_commit "$ZNUNY_DEV_DIR")
        if [ -n "$checkout_commit" ]; then
            if commits_equal "$checkout_commit" "$latest_commit"; then
                print_success "Up to date with remote (checkout: ${checkout_commit:0:7})"
                return 0
            fi
            print_warning "Checkout differs from remote: remote ${latest_commit}, checkout ${checkout_commit:0:7}"
            return 1
        fi
        if [ -n "${BUILD_COMMIT:-}" ]; then
            if commits_equal "$BUILD_COMMIT" "$latest_commit"; then
                print_success "Up to date with remote (commit: $latest_commit)"
                return 0
            fi
            print_warning "Remote differs from RELEASE build commit: remote ${latest_commit}, build ${BUILD_COMMIT:0:7}"
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
    local checkout_commit=""

    echo ""
    print_header "Version Check"

    if [ -f "$release_file" ]; then
        # shellcheck source=../../RELEASE
        source "$release_file"
    fi

    local get_latest_result
    get_latest_result=$(get_latest_version --path "$ZNUNY_DEV_DIR" 2>/dev/null)
    local latest_version="undef"
    local latest_commit="undef"
    if [ -n "$get_latest_result" ]; then
        latest_version=$(echo "$get_latest_result" | sed -n '1p')
        latest_commit=$(echo "$get_latest_result" | sed -n '2p')
    fi
    checkout_commit=$(get_checkout_commit "$ZNUNY_DEV_DIR")

    print_table "Latest version (remote)" "${latest_version}"
    print_table "Checkout commit (local)" "${checkout_commit:-unknown}"
    print_table "Latest commit (remote)" "${latest_commit}"
    print_table "Build commit (RELEASE)" "${BUILD_COMMIT:-Unknown}"
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
        print_table "Build commit (RELEASE)" "${BUILD_COMMIT:-Unknown}"
        print_table "Build Branch" "${BUILD_BRANCH:-Unknown}"
    else
        current_version="1.0.0"
        print_table "Version" "$current_version"
        print_table "Build Date" "Unknown"
        print_table "Build commit (RELEASE)" "Unknown"
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

    if echo "$output" | grep -qE "New version available|Checkout differs from remote|Remote differs from RELEASE"; then
        echo "$output"
        print_status "New version available, please run 'git pull' and 'zd version' to check for updates."
        echo ""
    fi

    if [ -f "$SCRIPT_DIR/env.sh" ]; then
        "$SCRIPT_DIR/env.sh" --set-var ZD_LAST_VERSION_CHECK_DATE "$today" >/dev/null 2>/dev/null || true
    fi
    return 0
}
