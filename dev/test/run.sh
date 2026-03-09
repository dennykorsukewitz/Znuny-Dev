#!/bin/bash

# Test Runner for Znuny Development Scripts
# Executes all test suites and provides summary

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test configuration (run.sh lives in dev/test/)
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")/../scripts" && pwd)"
VERBOSE=false
RUN_SPECIFIC=""

# Function to show help
show_help() {
    echo "Znuny Development Scripts Test Runner"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --verbose, -v     Show verbose output with detailed test information"
    echo "                    - File sizes, permissions, and modification times"
    echo "                    - Command output and exit codes"
    echo "                    - String lengths and content previews"
    echo "                    - Parent directory contents on failures"
    echo "  --test, -t <name> Run specific test suite"
    echo "  --help, -h        Show this help"
    echo ""
    echo "Available test suites:"
    echo "  common                  # Test common.sh functions"
    echo "  instance                # Test instance.sh functions"
    echo "  env                     # Test env.sh functions"
    echo "  repository              # Test repository.sh functions"
    echo "  compose                 # Test compose.sh functions"
    echo "  znuny-dev               # Test znuny-dev.sh functions"
    echo "  update-config-custom    # Test update_config_custom (tests/docker/update-config-custom.sh)"
    echo "  instance-create         # Real zd create tests (tests/instance/create.sh)"
    echo ""
    echo "Examples:"
    echo "  $0                      # Run all tests (compact output)"
    echo "  $0 --verbose            # Run all tests with detailed debug information"
    echo "  $0 --test instance      # Run only instance.sh tests"
    echo "  $0 -v -t instance       # Run instance tests with verbose output"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --test|-t)
            RUN_SPECIFIC="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Function to print header
print_header() {
    echo ""
    echo "=========================================="
    echo -e "${CYAN}$1${NC}"
    echo "=========================================="
}

# Resolve test file path: <name>.sh, instance/create.sh, or docker/update-config-custom.sh
get_test_file() {
    local test_name="$1"
    if [ "$test_name" = "instance-create" ]; then
        echo "$TEST_DIR/tests/instance/create.sh"
    elif [ "$test_name" = "update-config-custom" ]; then
        echo "$TEST_DIR/tests/docker/update-config-custom.sh"
    else
        echo "$TEST_DIR/tests/$test_name.sh"
    fi
}

# Function to run a test suite
run_test_suite() {
    local test_name="$1"
    local test_file
    test_file=$(get_test_file "$test_name")

    if [ ! -f "$test_file" ]; then
        echo -e "${RED}Error: Test file not found: $test_file${NC}"
        return 1
    fi

    print_header "Running $test_name Tests"

    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}🔍 Verbose mode enabled - showing detailed test information${NC}"
        echo ""
    fi

    # Make test file executable
    chmod +x "$test_file"

    # Run the test
    if [ "$VERBOSE" = true ]; then
        export VERBOSE_TESTS=true
        bash "$test_file"
    else
        bash "$test_file"
    fi

    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ $test_name tests passed${NC}"
    else
        echo -e "${RED}✗ $test_name tests failed${NC}"
    fi

    return $exit_code
}

# Function to run all tests
run_all_tests() {
    local total_suites=0
    local passed_suites=0
    local failed_suites=0

    print_header "Znuny Development Scripts Test Suite"
    echo -e "${BLUE}Test Directory: $TEST_DIR${NC}"
    echo -e "${BLUE}Script Directory: $SCRIPT_DIR${NC}"
    echo ""

    # List of all test suites (<name>.sh and instance/create.sh)
    local test_suites=("common" "instance" "env" "repository" "compose" "znuny-dev" "update-config-custom" "instance-create")

    for suite in "${test_suites[@]}"; do
        # In CI, skip instance-create (git clone + zd create --start; needs Docker/network)
        if [ "$suite" = "instance-create" ] && [ "${CI_MODE:-}" = "true" ]; then
            echo -e "${YELLOW}⚠ Skipping $suite tests (CI_MODE=true)${NC}"
            continue
        fi

        local test_file
        test_file=$(get_test_file "$suite")
        if [ -f "$test_file" ]; then
            total_suites=$((total_suites + 1))

            if run_test_suite "$suite"; then
                passed_suites=$((passed_suites + 1))
            else
                failed_suites=$((failed_suites + 1))
            fi
        else
            echo -e "${YELLOW}⚠ Skipping $suite tests (test file not found)${NC}"
        fi
    done

    # Print final summary
    echo ""
    print_header "Test Suite Summary"
    echo -e "Total test suites: $total_suites"
    echo -e "${GREEN}Passed: $passed_suites${NC}"
    echo -e "${RED}Failed: $failed_suites${NC}"

    if [ $failed_suites -eq 0 ]; then
        echo -e "${GREEN}🎉 All test suites passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Some test suites failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    # Load assertion functions
    source "$TEST_DIR/utils/assertions.sh"

    if [ -n "$RUN_SPECIFIC" ]; then
        # Run specific test suite
        run_test_suite "$RUN_SPECIFIC"
    else
        # Run all tests
        run_all_tests
    fi
}

# Run main function
main "$@"
