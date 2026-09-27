#!/bin/bash

# Write a release: RELEASE, CHANGELOG.md, RELEASE.md, and the README badge version.
# Then commit those files and tag the version.
# Asks again before pushing. The tag push starts .github/workflows/release.yml.

set -e

# Define ZNUNY_DEV_DIR if not set (e.g. when script is run standalone)
if [ -z "${ZNUNY_DEV_DIR:-}" ]; then
    ZNUNY_DEV_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
fi

# Load common functions (needed for show_help output)
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

RELEASE_FILE="$ZNUNY_DEV_DIR/RELEASE"

read_release_file() {
    VERSION=""
    if [ -f "$RELEASE_FILE" ]; then
        # shellcheck source=../../RELEASE
        source "$RELEASE_FILE"
    fi
}

next_patch_version() {
    local major minor patch
    if [ -z "${VERSION:-}" ]; then
        echo "1.0.0"
        return
    fi
    major=$(echo "$VERSION" | cut -d. -f1)
    minor=$(echo "$VERSION" | cut -d. -f2)
    patch=$(echo "$VERSION" | cut -d. -f3)
    patch=$((patch + 1))
    echo "$major.$minor.$patch"
}

# Show help
show_help() {
    read_release_file
    print_header "Znuny Development Environment – Release Management"
    print_header "==================================================="
    echo ""
    print "Asks whether to release and which version to write."
    print "Updates RELEASE, stamps CHANGELOG.md, rewrites RELEASE.md, and sets the README badge version."
    print "The next UNRELEASED section is taken from CHANGELOG.template.md."
    print "Before the commit, shows the RELEASE diff, the CHANGELOG.md stamp, and the new RELEASE.md."
    print "Commits those files and tags the version, then asks before pushing."
    print "Stops when other files are uncommitted, or when UNRELEASED has no list items."
    print "If the push is declined, asks whether to undo that commit and its local tag. File changes stay staged."
    print "The tag workflow creates the GitHub release after the tag is pushed."
    echo ""
    print_subheader "Current release:"
    if [ -n "${VERSION:-}" ]; then
        print_command "Version"              "$VERSION"
    else
        print_command "Version"              "(no RELEASE file)"
    fi
    echo ""
    print_subheader "Usage:"
    print_command "zd release [version]"    ""
    echo ""
    print_subheader "Arguments:"
    print_command "version"                 "Suggested version (e.g. 1.2.3)"
    print_command ""                        "If omitted, the suggestion is the next patch"
    echo ""
    print_subheader "Options:"
    print_command "--help, -h"              "Show this help"
    echo ""
    print_subheader "Examples:"
    print_command "zd release"              "Ask, suggest next patch"
    print_command "zd release 1.2.3"        "Ask, suggest 1.2.3"
    echo ""
    exit 0
}

load_environment

# load_environment may retarget ZNUNY_DEV_DIR
RELEASE_FILE="$ZNUNY_DEV_DIR/RELEASE"
CHANGELOG_FILE="$ZNUNY_DEV_DIR/CHANGELOG.md"
CHANGELOG_TEMPLATE="$ZNUNY_DEV_DIR/CHANGELOG.template.md"
NOTES_FILE="$ZNUNY_DEV_DIR/RELEASE.md"
README_FILE="$ZNUNY_DEV_DIR/README.md"

# Check for help flag
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    show_help
fi

read_release_file
CURRENT_VERSION="${VERSION:-}"

if [ -n "${1:-}" ]; then
    SUGGESTED_VERSION="$1"
else
    SUGGESTED_VERSION=$(next_patch_version)
fi

echo ""
if [ -n "$CURRENT_VERSION" ]; then
    print_table "Current version" "$CURRENT_VERSION"
else
    print_table "Current version" "(none)"
fi
echo ""

read_input BUILD_VERSION "Version" "$SUGGESTED_VERSION"
if [ -z "$BUILD_VERSION" ]; then
    print_error "Version is required"
    exit 1
fi

case "$BUILD_VERSION" in
    v*)
        print_error "Version must not start with v"
        exit 1
        ;;
    *[[:space:]]*|*/*|*..*)
        print_error "Version is not a valid tag name: $BUILD_VERSION"
        exit 1
        ;;
esac

if ! git -C "$ZNUNY_DEV_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_error "Not a git repository: $ZNUNY_DEV_DIR"
    exit 1
fi
if git -C "$ZNUNY_DEV_DIR" rev-parse -q --verify "refs/tags/${BUILD_VERSION}" >/dev/null; then
    print_error "Tag ${BUILD_VERSION} already exists"
    exit 1
fi
if git -C "$ZNUNY_DEV_DIR" ls-remote --tags origin "refs/tags/${BUILD_VERSION}" | grep -q .; then
    print_error "Tag ${BUILD_VERSION} already exists on origin"
    exit 1
fi

if [ ! -f "$CHANGELOG_FILE" ]; then
    print_error "CHANGELOG.md not found: $CHANGELOG_FILE"
    exit 1
fi
if [ ! -s "$CHANGELOG_TEMPLATE" ]; then
    print_error "CHANGELOG template not found: $CHANGELOG_TEMPLATE"
    exit 1
fi
if ! grep -q '^## \[UNRELEASED\]' "$CHANGELOG_FILE"; then
    print_error "CHANGELOG.md has no ## [UNRELEASED] heading"
    exit 1
fi
if ! awk -v template="$CHANGELOG_TEMPLATE" '
    BEGIN {
        while ((getline line < template) > 0) {
            if (line ~ /^- /) {
                placeholders[line] = 1
            }
        }
        close(template)
    }
    /^## \[UNRELEASED\]/ { in_section = 1; next }
    in_section && /^## \[/ { exit }
    in_section && /^- .+/ && !($0 in placeholders) { found = 1; exit }
    END { exit found ? 0 : 1 }
' "$CHANGELOG_FILE"; then
    print_error "CHANGELOG.md UNRELEASED section has no list items"
    exit 1
fi

other_changes=0
while IFS= read -r status_line; do
    [ -z "$status_line" ] && continue
    path="${status_line:3}"
    case "$path" in
        *" -> "*) path="${path##* -> }" ;;
    esac
    path="${path#\"}"
    path="${path%\"}"
    case "$path" in
        RELEASE|CHANGELOG.md|RELEASE.md) continue ;;
    esac
    if [ "$other_changes" -eq 0 ]; then
        print_error "Other uncommitted changes. Commit or stash them before release:"
        other_changes=1
    fi
    printf '  %s\n' "$path"
done < <(git -C "$ZNUNY_DEV_DIR" status --porcelain)
if [ "$other_changes" -eq 1 ]; then
    exit 1
fi

if ! confirm "Release $BUILD_VERSION now? This commits and tags." "n"; then
    print_status "Release cancelled."
    exit 0
fi

# Go to project root
cd "$ZNUNY_DEV_DIR"

# Get current build information
BUILD_DATE=$(date '+%Y-%m-%d %H:%M:%S')
BUILD_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

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

if [ ! -f "$README_FILE" ]; then
    print_error "README.md not found: $README_FILE"
    exit 1
fi
print_status "Setting README badge version to ${BUILD_VERSION}..."
sed -i.tmp -E \
    -e "s#(Znuny-Dev/)[0-9]+\\.[0-9]+\\.[0-9]+(/dev)#\\1${BUILD_VERSION}\\2#" \
    -e "s#(compare/)[0-9]+\\.[0-9]+\\.[0-9]+(\\.\\.\\.dev)#\\1${BUILD_VERSION}\\2#" \
    "$README_FILE"
rm -f "$README_FILE.tmp"
if ! grep -q "Znuny-Dev/${BUILD_VERSION}/dev" "$README_FILE" || ! grep -q "compare/${BUILD_VERSION}...dev" "$README_FILE"; then
    print_error "README.md version links were not updated"
    exit 1
fi
print_success "README.md updated."

# Date in CHANGELOG / RELEASE.md is the day only (YYYY-MM-DD).
RELEASE_DAY=$(date '+%Y-%m-%d')

print_status "Stamping CHANGELOG.md as ${BUILD_VERSION} (${RELEASE_DAY})..."
changelog_tmp=$(mktemp)
awk -v version="$BUILD_VERSION" -v day="$RELEASE_DAY" -v template="$CHANGELOG_TEMPLATE" '
    BEGIN {
        first = 1
        while ((getline line < template) > 0) {
            if (first && line ~ /^## /) {
                line = "## [UNRELEASED] - YYYY-MM-DD"
            }
            first = 0
            block = block line "\n"
        }
        close(template)
    }
    !done && /^## \[UNRELEASED\]/ {
        printf "%s", block
        print ""
        print "## [" version "] - " day
        done = 1
        next
    }
    { print }
' "$CHANGELOG_FILE" >"$changelog_tmp"
mv "$changelog_tmp" "$CHANGELOG_FILE"
print_success "CHANGELOG.md updated."

print_status "Writing RELEASE.md from the ${BUILD_VERSION} changelog section..."
notes_tmp=$(mktemp)
awk -v version="$BUILD_VERSION" -v day="$RELEASE_DAY" '
    BEGIN {
        escaped = version
        gsub(/\./, "\\.", escaped)
        start = "^## \\[" escaped "\\] - " day "$"
        capture = 0
    }
    $0 ~ start {
        capture = 1
        print "# [" version "] - " day
        next
    }
    capture && /^## \[/ { exit }
    capture {
        if ($0 ~ /^### /) {
            sub(/^### /, "## ")
        }
        print
    }
' "$CHANGELOG_FILE" >"$notes_tmp"
if [ ! -s "$notes_tmp" ]; then
    rm -f "$notes_tmp"
    print_error "Could not build RELEASE.md from CHANGELOG.md"
    exit 1
fi
mv "$notes_tmp" "$NOTES_FILE"
print_success "RELEASE.md updated."

echo ""
print_header "Review ${BUILD_VERSION}"
print_header "===================="
echo ""

print_header "RELEASE"
print_header "--------------------"

git --no-pager diff -- "$RELEASE_FILE" || true
echo ""

print_header "CHANGELOG.md"
print_header "--------------------"

git --no-pager diff -U2 -- "$CHANGELOG_FILE" || true
echo ""

print_header "RELEASE.md"
print_header "--------------------"

cat "$NOTES_FILE"
echo ""

print_header "README.md"
print_header "--------------------"

git --no-pager diff -U0 -- "$README_FILE" || true

echo ""
print_header "Committing ${BUILD_VERSION}"
print_header "===================="
echo ""

git add -- "$RELEASE_FILE" "$CHANGELOG_FILE" "$NOTES_FILE" "$README_FILE"
git commit -m "$(cat <<EOF
Release ${BUILD_VERSION}

EOF
)"
git tag -a "$BUILD_VERSION" -m "Release ${BUILD_VERSION}"
echo ""
print_success "Committed and tagged ${BUILD_VERSION}."

if ! confirm "Push branch and tag ${BUILD_VERSION} now?" "n"; then
    print_status "Not pushed. Tag ${BUILD_VERSION} stays local."
    print_status "The GitHub release is created when that tag is pushed."
    if confirm "Undo the last commit?" "n"; then
        if [ "$(git rev-parse HEAD)" != "$(git rev-parse "${BUILD_VERSION}^{commit}")" ]; then
            print_error "Tag ${BUILD_VERSION} does not point at HEAD. Commit was left in place."
            cd - > /dev/null 2>&1
            exit 1
        fi
        git tag -d "$BUILD_VERSION"
        git reset --soft HEAD~1
        print_success "Removed commit and tag ${BUILD_VERSION}. File changes stay staged."
    fi
    cd - > /dev/null 2>&1
    exit 0
fi

if git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
    git push origin HEAD "refs/tags/${BUILD_VERSION}"
else
    git push -u origin HEAD "refs/tags/${BUILD_VERSION}"
fi
print_success "Pushed branch and tag ${BUILD_VERSION}. The tag workflow creates the GitHub release."

# Go back to previous directory
cd - > /dev/null 2>&1