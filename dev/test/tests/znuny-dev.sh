#!/bin/bash

# Test Suite for znuny-dev.sh (smoke tests)
#
# What is tested:
# ---------------
# 1. zd help     – exits 0 and shows usage (create, setup-framework, etc.)
# 2. zd version  – exits 0 and shows version info
# 3. zd examples – exits 0

TEST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
ZD="${ZD_CMD:-$ROOT/znuny-dev.sh}"

source "$TEST_DIR/utils/assertions.sh"

test_zd_help() {
    echo ""
    echo "Testing zd help..."

    local out
    out=$("$ZD" help 2>&1) || true
    local ret=$?
    assert_equal "0" "$ret" "zd help exits 0"
    assert_contains "$out" "create" "zd help mentions create"
    assert_contains "$out" "setup-framework" "zd help mentions setup-framework"
}

test_zd_version() {
    echo ""
    echo "Testing zd version..."

    local out
    out=$("$ZD" version 2>&1) || true
    local ret=$?
    assert_equal "0" "$ret" "zd version exits 0"
    assert_contains "$out" "Version" "zd version shows Version"
}

test_zd_examples() {
    echo ""
    echo "Testing zd examples..."

    local out
    out=$("$ZD" examples 2>&1) || true
    local ret=$?
    assert_equal "0" "$ret" "zd examples exits 0"
}

run_all_tests() {
    test_zd_help
    test_zd_version
    test_zd_examples
    print_test_summary
}

run_all_tests
