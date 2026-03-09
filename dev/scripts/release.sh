#!/bin/bash

# Update RELEASE file with current build information
# This script should be run during the build/release process

set -e

# Define ZNUNY_DEV_DIR if not set (e.g. when script is run standalone)
if [ -z "${ZNUNY_DEV_DIR:-}" ]; then
    ZNUNY_DEV_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
fi

# Load common functions (needed for show_help output)
source "$(dirname "$0")/common.sh"

# Show help
show_help() {
    print_header "Znuny Development Environment – Release Management"
    print_header "==================================================="
    echo ""
    print_subheader "Usage:"
    print_command "zd release [version]" ""
    echo ""
    print_subheader "Arguments:"
    print_command "version"              "Version number (e.g. 1.2.3)"
    print_command ""                     "If not provided, patch version is auto-incremented"
    echo ""
    print_subheader "Options:"
    print_command "--help, -h" "Show this help"
    echo ""
    print_subheader "Examples:"
    print_command "zd release"                     "Auto-increment: 0.0.1 → 0.0.2"
    print_command "zd release 1.2.3"               "Set version to 1.2.3"
    echo ""
    exit 0
}

# Check for help flag
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    show_help
fi

load_environment

# Get project root using common function
RELEASE_FILE="$ZNUNY_DEV_DIR/RELEASE"

# Get current version from RELEASE file or use parameter
if [ -n "${1:-}" ]; then
    # Version provided as parameter
    BUILD_VERSION="$1"
else
    # Read current version and increment patch
    if [ -f "$RELEASE_FILE" ]; then
        source "$RELEASE_FILE"
        # Parse version (e.g., 0.0.1 -> 0.0.2)
        MAJOR=$(echo "$VERSION" | cut -d. -f1)
        MINOR=$(echo "$VERSION" | cut -d. -f2)
        PATCH=$(echo "$VERSION" | cut -d. -f3)
        PATCH=$((PATCH + 1))
        BUILD_VERSION="$MAJOR.$MINOR.$PATCH"
    else
        BUILD_VERSION="1.0.0"
    fi
fi

# Go to project root
cd "$ZNUNY_DEV_DIR"

# Get current build information
BUILD_DATE=$(date '+%Y-%m-%d %H:%M:%S')
BUILD_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

print_header "Updating RELEASE file"
print_header "===================="
echo ""

print_table "Version" "$BUILD_VERSION"
print_table "Build Date" "$BUILD_DATE"
print_table "Build Commit" "$BUILD_COMMIT"
print_table "Build Branch" "$BUILD_BRANCH"
echo ""
print_status "RELEASE file location: $RELEASE_FILE"

# Update RELEASE file
if [ -f "$RELEASE_FILE" ]; then
    print_status "Updating existing RELEASE file..."

    # Create backup
    cp "$RELEASE_FILE" "$RELEASE_FILE.bak"

    # Update version information
    sed -i.tmp "s|^VERSION=.*|VERSION=$BUILD_VERSION|" "$RELEASE_FILE"
    sed -i.tmp "s|^BUILD_DATE=.*|BUILD_DATE=\"$BUILD_DATE\"|" "$RELEASE_FILE"
    sed -i.tmp "s|^BUILD_COMMIT=.*|BUILD_COMMIT=$BUILD_COMMIT|" "$RELEASE_FILE"
    sed -i.tmp "s|^BUILD_BRANCH=.*|BUILD_BRANCH=$BUILD_BRANCH|" "$RELEASE_FILE"

    # Clean up temporary files
    rm -f "$RELEASE_FILE.tmp"

    print_success "RELEASE file updated successfully!"
else
    print_error "RELEASE file not found: $RELEASE_FILE"
    exit 1
fi

# Go back to previous directory
cd - > /dev/null 2>&1