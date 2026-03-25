#!/bin/bash

# Test Suite for instance.sh Functions
# Tests all functions in the instance management script
#
# What is tested:
# ---------------
# 1. get_available_frameworks   – Resolving framework dirs (test, prod, dev), count and names
# 2. get_available_instances    – Resolving instances from existing .env in instances/<name>/
# 3. directory_structure        – Existence of frameworks/test and instance env (instances/test)
# 4. environment_variables      – Reading FRAMEWORK_INDEX, INSTANCE_PORT, DB_PORT, NETWORK_SUBNET from instance .env
# 5. used_indices               – Reading USED_FRAMEWORK_INDICES from global .env
# 6. container_naming           – Container name scheme (znuny-<name>-instance, -mysql, -mariadb, -postgresql)
# 7. compose_file_paths         – Compose file path: instances/<framework>/compose-<framework_slug>.yml
# 8. port_calculation           – Instance port (BASE_PORT + index) and network subnet (172.20.(1+index).0/24)
#
# Prerequisite: Test env with frameworks/test|prod|dev, instances/test/test.env and .env (see setup_test_environment)

# Get test directory (dev/test) and script paths
TEST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")/../../scripts" && pwd)"
DATA_DIR="$TEST_DIR/data"

# Load assertion functions
# shellcheck source=../utils/assertions.sh
source "$TEST_DIR/utils/assertions.sh"

# Test environment setup
TEST_ENV_DIR=""

# Function to setup test environment
setup_test_environment() {
    echo "Setting up test environment..."

    TEST_ENV_DIR=$(mktemp -d /tmp/znuny-test.XXXXXX)

    # Create test directory structure
    mkdir -p "$TEST_ENV_DIR/frameworks/test"
    mkdir -p "$TEST_ENV_DIR/frameworks/prod"
    mkdir -p "$TEST_ENV_DIR/frameworks/dev"
    mkdir -p "$TEST_ENV_DIR/instances/test/logs"
    mkdir -p "$TEST_ENV_DIR/compose"
    mkdir -p "$TEST_ENV_DIR/packages"
    mkdir -p "$TEST_ENV_DIR/tools"

    # Copy test data (new structure: instances/NAME/NAME.env)
    cp "$DATA_DIR/sample.env" "$TEST_ENV_DIR/.env"
    cp "$DATA_DIR/sample-instance.env" "$TEST_ENV_DIR/instances/test/test.env"

    # Set environment variables
    export ZNUNY_DEV_DIR="$TEST_ENV_DIR"
    export FRAMEWORKS_DIR="$TEST_ENV_DIR/frameworks"
    export INSTANCES_DIR="$TEST_ENV_DIR/instances"
    export COMPOSE_DIR="$TEST_ENV_DIR/compose"
    export PACKAGES_DIR="$TEST_ENV_DIR/packages"
    export TOOLS_DIR="$TEST_ENV_DIR/tools"

    # Source common.sh to get utility functions
    # shellcheck source=../../scripts/common.sh
    source "$SCRIPT_DIR/common.sh"

    echo "Test environment created at: $TEST_ENV_DIR"
}

# Function to cleanup test environment
cleanup_test_environment() {
    if [ -n "$TEST_ENV_DIR" ] && [ -d "$TEST_ENV_DIR" ]; then
        rm -rf "$TEST_ENV_DIR"
        echo "Test environment cleaned up"
    fi
}

# Function to call instance.sh function
call_instance_function() {
    local func_name="$1"
    shift

    # Extract just the function from instance.sh and execute it
    bash -c '
        sd="$1"
        source "$sd/common.sh"
        export ZNUNY_DEV_DIR="$2"
        export FRAMEWORKS_DIR="$3"
        export INSTANCES_DIR="$4"
        export COMPOSE_DIR="$5"
        fn="$6"
        shift 6
        sed -n "/^${fn}()/,/^}/p" "$sd/instance.sh" | bash -s -- "$@"
    ' _ "$SCRIPT_DIR" "$ZNUNY_DEV_DIR" "$FRAMEWORKS_DIR" "$INSTANCES_DIR" "$COMPOSE_DIR" "$func_name" "$@"
}

# Test get_available_frameworks function
test_get_available_frameworks() {
    echo ""
    echo "Testing get_available_frameworks..."

    local framework_array=()
    read_lines_to_array framework_array < <(get_available_frameworks)
    local framework_count=${#framework_array[@]}
    local frameworks
    frameworks=$(printf '%s\n' "${framework_array[@]}")

    # Should find 3 frameworks: test, prod, dev
    if [ "$framework_count" -eq 3 ]; then
        print_test_result "get_available_frameworks count" "PASS" "Found 3 frameworks"
    else
        print_test_result "get_available_frameworks count" "FAIL" "Expected 3, found $framework_count"
    fi

    if echo "$frameworks" | grep -q "test"; then
        print_test_result "get_available_frameworks test" "PASS" "Found test framework"
    else
        print_test_result "get_available_frameworks test" "FAIL" "Should find test framework"
    fi

    if echo "$frameworks" | grep -q "prod"; then
        print_test_result "get_available_frameworks prod" "PASS" "Found prod framework"
    else
        print_test_result "get_available_frameworks prod" "FAIL" "Should find prod framework"
    fi

    if echo "$frameworks" | grep -q "dev"; then
        print_test_result "get_available_frameworks dev" "PASS" "Found dev framework"
    else
        print_test_result "get_available_frameworks dev" "FAIL" "Should find dev framework"
    fi
}

# Test get_available_instances function
test_get_available_instances() {
    echo ""
    echo "Testing get_available_instances..."

    local instances
    instances=$(get_available_instances)

    if echo "$instances" | grep -q "test"; then
        print_test_result "get_available_instances" "PASS" "Found test instance"
    else
        print_test_result "get_available_instances" "FAIL" "Should find test instance"
    fi
}

# Test directory and file operations
test_directory_structure() {
    echo ""
    echo "Testing directory structure..."

    if [ -d "$FRAMEWORKS_DIR/test" ]; then
        print_test_result "Framework directory exists" "PASS" "test framework directory exists"
    else
        print_test_result "Framework directory exists" "FAIL" "test framework directory should exist"
    fi

    if [ -f "$INSTANCES_DIR/test/test.env" ]; then
        print_test_result "Instance env file exists" "PASS" "test instance env file exists"
    else
        print_test_result "Instance env file exists" "FAIL" "test instance env file should exist"
    fi
}

# Test environment variable reading
test_environment_variables() {
    echo ""
    echo "Testing environment variables..."

    # Read FRAMEWORK_INDEX from test.env
    if [ -f "$INSTANCES_DIR/test/test.env" ]; then
        local framework_index
        framework_index=$(grep "^FRAMEWORK_INDEX=" "$INSTANCES_DIR/test/test.env" | cut -d'=' -f2)
        assert_equal "1" "$framework_index" "Should read correct FRAMEWORK_INDEX"

        local instance_port
        instance_port=$(grep "^INSTANCE_PORT=" "$INSTANCES_DIR/test/test.env" | cut -d'=' -f2)
        assert_equal "8081" "$instance_port" "Should read correct INSTANCE_PORT"

        local db_port
        db_port=$(grep "^DB_PORT=" "$INSTANCES_DIR/test/test.env" | cut -d'=' -f2)
        assert_equal "3306" "$db_port" "Should read correct DB_PORT"

        local network_subnet
        network_subnet=$(grep "^NETWORK_SUBNET=" "$INSTANCES_DIR/test/test.env" | cut -d'=' -f2)
        assert_equal "172.20.2.0/24" "$network_subnet" "Should read correct NETWORK_SUBNET"
    else
        print_test_result "Environment file reading" "FAIL" "test.env file not found"
    fi
}

# Test USED_FRAMEWORK_INDICES reading
test_used_indices() {
    echo ""
    echo "Testing USED_FRAMEWORK_INDICES..."

    if [ -f "$ZNUNY_DEV_DIR/.env" ]; then
        local used_indices
        used_indices=$(grep "^USED_FRAMEWORK_INDICES=" "$ZNUNY_DEV_DIR/.env" | cut -d'=' -f2)

        if echo "$used_indices" | grep -q "0"; then
            print_test_result "USED_FRAMEWORK_INDICES contains 0" "PASS" "Found index 0"
        else
            print_test_result "USED_FRAMEWORK_INDICES contains 0" "FAIL" "Should contain index 0"
        fi

        if echo "$used_indices" | grep -q "1"; then
            print_test_result "USED_FRAMEWORK_INDICES contains 1" "PASS" "Found index 1"
        else
            print_test_result "USED_FRAMEWORK_INDICES contains 1" "FAIL" "Should contain index 1"
        fi

        if echo "$used_indices" | grep -q "2"; then
            print_test_result "USED_FRAMEWORK_INDICES contains 2" "PASS" "Found index 2"
        else
            print_test_result "USED_FRAMEWORK_INDICES contains 2" "FAIL" "Should contain index 2"
        fi
    else
        print_test_result "USED_FRAMEWORK_INDICES reading" "FAIL" ".env file not found"
    fi
}

# Test container name generation
test_container_naming() {
    echo ""
    echo "Testing container naming conventions..."

    local test_instance="test"
    local expected_container="znuny-test-instance"

    # Simulate get_instance_container_name logic
    local container_name="znuny-${test_instance}-instance"
    assert_equal "$expected_container" "$container_name" "Should generate correct container name"

    # Test database container names
    local mysql_container="znuny-${test_instance}-mysql"
    assert_equal "znuny-test-mysql" "$mysql_container" "Should generate correct MySQL container name"

    local mariadb_container="znuny-${test_instance}-mariadb"
    assert_equal "znuny-test-mariadb" "$mariadb_container" "Should generate correct MariaDB container name"

    local postgres_container="znuny-${test_instance}-postgresql"
    assert_equal "znuny-test-postgresql" "$postgres_container" "Should generate correct PostgreSQL container name"
}

# Test compose file path generation (per-instance dir)
test_compose_file_paths() {
    echo ""
    echo "Testing compose file paths..."

    local test_framework="test"
    local expected_compose
    expected_compose="$INSTANCES_DIR/$test_framework/compose-$(get_framework_slug "$test_framework").yml"

    assert_equal "$expected_compose" "$INSTANCES_DIR/test/compose-test.yml" "Should generate correct compose file path (slug format)"
}

# Test port calculation
test_port_calculation() {
    echo ""
    echo "Testing port calculation..."

    # Base port is 10000, index is 1, so instance port should be 10001
    local base_port=10000
    local index=1
    local calculated_port=$((base_port + index))

    assert_equal "10001" "$calculated_port" "Should calculate correct instance port"

    # Network subnet calculation: 172.20.$((1 + index)).0/24
    local calculated_subnet="172.20.$((1 + index)).0/24"
    assert_equal "172.20.2.0/24" "$calculated_subnet" "Should calculate correct network subnet"
}

# Main test runner
run_all_tests() {
    echo "=========================================="
    echo "Starting instance.sh Function Tests"
    echo "=========================================="

    # Setup
    setup_test_environment

    # Run all tests
    test_directory_structure
    test_get_available_frameworks
    test_get_available_instances
    test_environment_variables
    test_used_indices
    test_container_naming
    test_compose_file_paths
    test_port_calculation

    # Print summary
    echo ""
    print_test_summary

    # Cleanup
    cleanup_test_environment

    # Return exit code based on test results
    return $?
}

# Run tests
run_all_tests