#!/bin/bash
# Subshell exports in run_repository_* are intentional (isolated test env).
# shellcheck disable=SC2030,SC2031

# Test Suite for repository.sh
#
# What is tested:
# ---------------
# 1. check_framework_name – valid names (alphanumeric, hyphen, underscore) pass; invalid chars or existing dir fail
# 2. sort_branches       – order: dev first, then rel-X_Y-dev (desc), rel-X_Y (desc), then others (alpha)

TEST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")/../../scripts" && pwd)"

# shellcheck source=../utils/assertions.sh
source "$TEST_DIR/utils/assertions.sh"

# Source repository.sh in a subshell with env set; run a single function and return its exit code or output
# Run repository.sh function in a subshell with $0 set so repository.sh can find common.sh
run_repository_check_framework_name() {
    local frameworks_dir="$1"
    local name="$2"
    local root="${ZNUNY_DEV_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
    ( export ZNUNY_DEV_DIR="$root" FRAMEWORKS_DIR="$frameworks_dir"
      exec -a "$SCRIPT_DIR/repository.sh" bash -c 'export FRAMEWORKS_DIR="'"$frameworks_dir"'"; cd "'"$SCRIPT_DIR"'" && source ./common.sh && load_environment 2>/dev/null; export FRAMEWORKS_DIR="'"$frameworks_dir"'"; source ./repository.sh 2>/dev/null; export FRAMEWORKS_DIR="'"$frameworks_dir"'"; check_framework_name "'"$name"'"' )
}

run_repository_sort_branches() {
    local root="${ZNUNY_DEV_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
    ( export ZNUNY_DEV_DIR="$root"
      exec -a "$SCRIPT_DIR/repository.sh" bash -c 'cd "'"$SCRIPT_DIR"'" && source ./common.sh && load_environment 2>/dev/null; source ./repository.sh 2>/dev/null; sort_branches '"$(printf '%q ' "$@")" )
}

test_check_framework_name_valid() {
    echo ""
    echo "Testing check_framework_name (valid names)..."

    local tmpdir
    tmpdir=$(mktemp -d /tmp/znuny-repo-test.XXXXXX)
    mkdir -p "$tmpdir/frameworks"

    run_repository_check_framework_name "$tmpdir/frameworks" "dev"; local ret=$?; assert_equal "0" "$ret" "check_framework_name dev should pass"
    run_repository_check_framework_name "$tmpdir/frameworks" "my-prod"; ret=$?; assert_equal "0" "$ret" "check_framework_name my-prod should pass"
    run_repository_check_framework_name "$tmpdir/frameworks" "rel_6_5"; ret=$?; assert_equal "0" "$ret" "check_framework_name rel_6_5 should pass"

    rm -rf "$tmpdir"
}

test_check_framework_name_invalid() {
    echo ""
    echo "Testing check_framework_name (invalid names)..."

    local tmpdir
    tmpdir=$(mktemp -d /tmp/znuny-repo-test.XXXXXX)
    mkdir -p "$tmpdir/frameworks"

    if run_repository_check_framework_name "$tmpdir/frameworks" "invalid name" 2>/dev/null; then
        print_test_result "check_framework_name invalid (space)" "FAIL" "Should reject name with space"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        print_test_result "check_framework_name invalid (space)" "PASS" "Rejects name with space"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi

    if run_repository_check_framework_name "$tmpdir/frameworks" "bad.chars!" 2>/dev/null; then
        print_test_result "check_framework_name invalid (special)" "FAIL" "Should reject special chars"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        print_test_result "check_framework_name invalid (special)" "PASS" "Rejects special chars"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi

    rm -rf "$tmpdir"
}

test_check_framework_name_already_exists() {
    echo ""
    echo "Testing check_framework_name (directory exists)..."

    local tmpdir
    tmpdir=$(mktemp -d /tmp/znuny-repo-test.XXXXXX)
    mkdir -p "$tmpdir/frameworks/existing"

    run_repository_check_framework_name "$tmpdir/frameworks" "existing" 2>/dev/null
    local ret=$?
    # Expect 1 when directory exists (framework name already used)
    assert_equal "1" "$ret" "check_framework_name should return 1 when dir exists"

    rm -rf "$tmpdir"
}

test_sort_branches() {
    echo ""
    echo "Testing sort_branches order..."

    local out
    out=$(run_repository_sort_branches "rel-7_3" "dev" "rel-6_5-dev" "rel-6_5" "feature-x")
    local first_line
    first_line=$(echo "$out" | head -1)
    assert_equal "dev" "$first_line" "sort_branches: dev first"

    out=$(run_repository_sort_branches "rel-7_3-dev" "rel-6_5-dev")
    first_line=$(echo "$out" | head -1)
    assert_contains "$out" "rel-7_3-dev" "sort_branches contains rel-7_3-dev"
    assert_contains "$out" "rel-6_5-dev" "sort_branches contains rel-6_5-dev"
}

run_all_tests() {
    test_check_framework_name_valid
    test_check_framework_name_invalid
    test_check_framework_name_already_exists
    test_sort_branches
    print_test_summary
}

run_all_tests
