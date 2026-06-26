#!/bin/bash

# Test Suite for common.sh
#
# What is tested:
# ---------------
# 1. print_* functions – produce non-empty output and do not crash
# 2. check_command     – returns 0 for existing command (e.g. true), non-zero for nonexistent
# 3. load_environment  – runs without error when ZNUNY_DEV_DIR is set (no .env required)

TEST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")/../../scripts" && pwd)"

# shellcheck source=../utils/assertions.sh
source "$TEST_DIR/utils/assertions.sh"

# Source common.sh once for this process
export ZNUNY_DEV_DIR="${ZNUNY_DEV_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# shellcheck source=../../scripts/common.sh
source "$SCRIPT_DIR/common.sh"

test_print_functions() {
    echo ""
    echo "Testing print_* functions..."

    local out
    out=$(print_status "test message" 2>&1)
    assert_contains "$out" "test message" "print_status contains message"
    assert_contains "$out" "INFO" "print_status contains INFO"

    out=$(print_success "ok" 2>&1)
    assert_contains "$out" "ok" "print_success contains message"

    out=$(print_warning "warn" 2>&1)
    assert_contains "$out" "warn" "print_warning contains message"

    out=$(print_error "err" 2>&1)
    assert_contains "$out" "err" "print_error contains message"

    out=$(print_header "Header" 2>&1)
    assert_contains "$out" "Header" "print_header contains text"
}

test_check_command() {
    echo ""
    echo "Testing check_command..."

    if check_command "true" 2>/dev/null; then
        print_test_result "check_command true" "PASS" "true is found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        print_test_result "check_command true" "FAIL" "true should be found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    if check_command "nonexistent_command_xyz_12345" 2>/dev/null; then
        print_test_result "check_command nonexistent" "FAIL" "Should not find fake command"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        print_test_result "check_command nonexistent" "PASS" "Correctly rejects fake command"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_load_environment() {
    echo ""
    echo "Testing load_environment..."

    local tmpdir
    tmpdir=$(mktemp -d /tmp/znuny-common-test.XXXXXX)
    if (
        export ZNUNY_DEV_DIR="$tmpdir"
        load_environment 2>/dev/null
    ); then
        print_test_result "load_environment no .env" "PASS" "Succeeds without .env"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        print_test_result "load_environment no .env" "FAIL" "Should succeed without .env"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
    rm -rf "$tmpdir"
}

run_all_tests() {
    test_print_functions
    test_check_command
    test_load_environment
    print_test_summary
}

run_all_tests
