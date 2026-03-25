#!/bin/bash

# Test Assertions Library
# Provides common assertion functions for testing

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test results
print_test_result() {
    local test_name="$1"
    local result="$2"
    local message="${3:-}"
    local verbose_info="${4:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$result" = "PASS" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ PASS${NC} $test_name"
        if [ -n "$message" ]; then
            echo -e "    ${BLUE}→${NC} $message"
        fi
        # Show verbose info only in verbose mode for passed tests
        if [ "$VERBOSE_TESTS" = true ] && [ -n "$verbose_info" ]; then
            echo -e "    ${BLUE}ℹ${NC} ${verbose_info}"
        fi
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ FAIL${NC} $test_name"
        if [ -n "$message" ]; then
            echo -e "    ${RED}→${NC} $message"
        fi
        # Always show verbose info for failed tests
        if [ -n "$verbose_info" ]; then
            echo -e "    ${YELLOW}ℹ${NC} ${verbose_info}"
        fi
    fi
}

# Function to print test summary
print_test_summary() {
    echo ""
    echo "=========================================="
    echo -e "${BLUE}Test Summary:${NC}"
    echo -e "  Tests run:    $TESTS_RUN"
    echo -e "  ${GREEN}Passed:       $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed:       $TESTS_FAILED${NC}"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "  ${GREEN}Result:       ALL TESTS PASSED${NC}"
        return 0
    else
        echo -e "  ${RED}Result:       SOME TESTS FAILED${NC}"
        return 1
    fi
}

# Assert that two values are equal
assert_equal() {
    local expected="$1"
    local actual="$2"
    local test_name="${3:-assert_equal}"

    local verbose_info=""
    if [ "$VERBOSE_TESTS" = true ]; then
        verbose_info="Expected length: ${#expected}, Actual length: ${#actual}"
    fi

    if [ "$expected" = "$actual" ]; then
        print_test_result "$test_name" "PASS" "Expected: '$expected', Got: '$actual'" "$verbose_info"
        return 0
    else
        # Enhanced failure info
        verbose_info="Expected length: ${#expected}, Actual length: ${#actual}"
        if [ ${#expected} -lt 100 ] && [ ${#actual} -lt 100 ]; then
            verbose_info="$verbose_info | Expected: '$expected' | Actual: '$actual'"
        fi
        print_test_result "$test_name" "FAIL" "Expected: '$expected', Got: '$actual'" "$verbose_info"
        return 1
    fi
}

# Assert that two values are not equal
assert_not_equal() {
    local expected="$1"
    local actual="$2"
    local test_name="${3:-assert_not_equal}"

    if [ "$expected" != "$actual" ]; then
        print_test_result "$test_name" "PASS" "Values are different as expected"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Values are equal: '$expected'"
        return 1
    fi
}

# Assert that a command returns success (exit code 0)
assert_success() {
    local command="$1"
    local test_name="${2:-assert_success}"

    local output=""
    local exit_code=0

    if [ "$VERBOSE_TESTS" = true ]; then
        output=$(eval "$command" 2>&1) || exit_code=$?
    else
        eval "$command" >/dev/null 2>&1 || exit_code=$?
    fi

    local verbose_info=""
    if [ "$VERBOSE_TESTS" = true ] && [ -n "$output" ]; then
        verbose_info="Output: ${output:0:200}"
        if [ ${#output} -gt 200 ]; then
            verbose_info="$verbose_info... (truncated)"
        fi
    fi

    if [ $exit_code -eq 0 ]; then
        print_test_result "$test_name" "PASS" "Command succeeded: $command" "$verbose_info"
        return 0
    else
        verbose_info="Exit code: $exit_code | $verbose_info"
        print_test_result "$test_name" "FAIL" "Command failed: $command" "$verbose_info"
        return 1
    fi
}

# Assert that a command returns failure (non-zero exit code)
assert_failure() {
    local command="$1"
    local test_name="${2:-assert_failure}"

    if ! eval "$command" >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS" "Command failed as expected: $command"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Command succeeded but should have failed: $command"
        return 1
    fi
}

# Assert that a file exists
assert_file_exists() {
    local file_path="$1"
    local test_name="${2:-assert_file_exists}"

    local verbose_info=""
    if [ -f "$file_path" ] && [ "$VERBOSE_TESTS" = true ]; then
        local file_size
        file_size=$(wc -c < "$file_path" 2>/dev/null || echo "unknown")
        local file_perms
        file_perms=$(stat -c '%A' "$file_path" 2>/dev/null || stat -f '%Sp' "$file_path" 2>/dev/null || echo "unknown")
        verbose_info="Size: ${file_size} bytes, Permissions: ${file_perms}"
    fi

    if [ -f "$file_path" ]; then
        print_test_result "$test_name" "PASS" "File exists: $file_path" "$verbose_info"
        return 0
    else
        # Show parent directory contents in verbose mode
        if [ "$VERBOSE_TESTS" = true ]; then
            local parent_dir
            parent_dir=$(dirname "$file_path")
            if [ -d "$parent_dir" ]; then
                local sample_files
                sample_files=$(find "$parent_dir" -mindepth 1 -maxdepth 1 -exec basename {} \; 2>/dev/null | head -5 | tr '\n' ', ' | sed 's/,$//')
                [ -n "$sample_files" ] || sample_files='none'
                verbose_info="Parent directory exists, files: $sample_files"
            else
                verbose_info="Parent directory does not exist: $parent_dir"
            fi
        fi
        print_test_result "$test_name" "FAIL" "File does not exist: $file_path" "$verbose_info"
        return 1
    fi
}

# Assert that a file does not exist
assert_file_not_exists() {
    local file_path="$1"
    local test_name="${2:-assert_file_not_exists}"

    if [ ! -f "$file_path" ]; then
        print_test_result "$test_name" "PASS" "File does not exist as expected: $file_path"
        return 0
    else
        print_test_result "$test_name" "FAIL" "File exists but should not: $file_path"
        return 1
    fi
}

# Assert that a directory exists
assert_dir_exists() {
    local dir_path="$1"
    local test_name="${2:-assert_dir_exists}"

    local verbose_info=""
    if [ -d "$dir_path" ] && [ "$VERBOSE_TESTS" = true ]; then
        local item_count
        item_count=$(find "$dir_path" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
        local dir_perms
        dir_perms=$(stat -c '%A' "$dir_path" 2>/dev/null || stat -f '%Sp' "$dir_path" 2>/dev/null || echo "unknown")
        verbose_info="Items: ${item_count}, Permissions: ${dir_perms}"
    fi

    if [ -d "$dir_path" ]; then
        print_test_result "$test_name" "PASS" "Directory exists: $dir_path" "$verbose_info"
        return 0
    else
        # Show parent directory info in verbose mode
        if [ "$VERBOSE_TESTS" = true ]; then
            local parent_dir
            parent_dir=$(dirname "$dir_path")
            if [ -d "$parent_dir" ]; then
                local sample_subdirs
                sample_subdirs=$(find "$parent_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | head -3 | tr '\n' ', ' | sed 's/,$//')
                [ -n "$sample_subdirs" ] || sample_subdirs='none'
                verbose_info="Parent directory exists, subdirs: $sample_subdirs"
            else
                verbose_info="Parent directory does not exist: $parent_dir"
            fi
        fi
        print_test_result "$test_name" "FAIL" "Directory does not exist: $dir_path" "$verbose_info"
        return 1
    fi
}

# Assert that a string contains a substring
assert_contains() {
    local string="$1"
    local substring="$2"
    local test_name="${3:-assert_contains}"

    local verbose_info=""
    if [ "$VERBOSE_TESTS" = true ]; then
        verbose_info="String length: ${#string}, Substring length: ${#substring}"
        if [ ${#string} -lt 150 ]; then
            verbose_info="$verbose_info | Full string: '$string'"
        fi
    fi

    if [[ "$string" == *"$substring"* ]]; then
        print_test_result "$test_name" "PASS" "String contains substring: '$substring'" "$verbose_info"
        return 0
    else
        # Show context around where substring should be
        if [ ${#string} -lt 200 ]; then
            verbose_info="$verbose_info | Full string: '$string'"
        else
            verbose_info="$verbose_info | String preview: '${string:0:100}...'"
        fi
        print_test_result "$test_name" "FAIL" "String does not contain substring: '$substring'" "$verbose_info"
        return 1
    fi
}

# Assert that a string does not contain a substring
assert_not_contains() {
    local string="$1"
    local substring="$2"
    local test_name="${3:-assert_not_contains}"

    if [[ "$string" != *"$substring"* ]]; then
        print_test_result "$test_name" "PASS" "String does not contain substring: '$substring'"
        return 0
    else
        print_test_result "$test_name" "FAIL" "String contains substring: '$substring'"
        return 1
    fi
}

# Assert that a variable is set (not empty)
assert_set() {
    local var_name="$1"
    local var_value="$2"
    local test_name="${3:-assert_set}"

    if [ -n "$var_value" ]; then
        print_test_result "$test_name" "PASS" "Variable $var_name is set: '$var_value'"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Variable $var_name is not set or empty"
        return 1
    fi
}

# Assert that a variable is not set (empty)
assert_not_set() {
    local var_name="$1"
    local var_value="$2"
    local test_name="${3:-assert_not_set}"

    if [ -z "$var_value" ]; then
        print_test_result "$test_name" "PASS" "Variable $var_name is not set as expected"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Variable $var_name is set but should not be: '$var_value'"
        return 1
    fi
}

# Function to setup test environment
setup_test_env() {
    local test_dir="$1"

    # Create temporary test directory
    if [ -z "$test_dir" ]; then
        test_dir="/tmp/znuny-test-$$"
    fi

    mkdir -p "$test_dir"
    echo "$test_dir"
}

# Function to cleanup test environment
cleanup_test_env() {
    local test_dir="$1"

    if [ -n "$test_dir" ] && [ -d "$test_dir" ]; then
        rm -rf "$test_dir"
    fi
}

# Export assertion functions
export -f print_test_result
export -f print_test_summary
export -f assert_equal
export -f assert_not_equal
export -f assert_success
export -f assert_failure
export -f assert_file_exists
export -f assert_file_not_exists
export -f assert_dir_exists
export -f assert_contains
export -f assert_not_contains
export -f assert_set
export -f assert_not_set
export -f setup_test_env
export -f cleanup_test_env
