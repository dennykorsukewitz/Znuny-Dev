# Znuny Development Scripts Test Suite

This folder contains tests for the individual script files of the Znuny Development Environment.

## Structure

```text
dev/test/
├── README.md                # This file
├── data/                    # Test data and mock files
│   ├── sample.env
│   ├── sample-instance.env
│   └── mock-frameworks/
├── run.sh                   # Run all tests (entry point)
├── utils/                   # Test utilities
│   └── assertions.sh        # Assertion functions
└── tests/                   # Test scripts (no tests directly under dev/test/)
    ├── instance.sh          # Tests for instance.sh (get_available_frameworks, ports, compose paths, etc.)
    ├── repository.sh        # Tests for repository.sh (check_framework_name, sort_branches)
    ├── common.sh            # Tests for common.sh (print_*, check_command, load_environment)
    ├── znuny-dev.sh         # Smoke tests for znuny-dev.sh (help, version, examples)
    └── instance/
        └── create.sh        # Real zd create tests (all parameters, env + compose)
```

## Usage

### Run all tests

```bash
./dev/test/run.sh
```

Runs all suites: common, instance, env (if present), repository, compose (if present), znuny-dev, and **instance-create** (`tests/instance/create.sh`). The last one performs real `zd create` runs (needs network and write access to frameworks/ and instances/).

### Run individual test suites

```bash
./dev/test/tests/instance.sh
./dev/test/tests/repository.sh
./dev/test/tests/common.sh
./dev/test/tests/znuny-dev.sh
./dev/test/tests/instance/create.sh
```

### Tests with verbose output

```bash
./dev/test/run.sh --verbose
```

### Run specific test suite

```bash
./dev/test/run.sh --test instance
./dev/test/run.sh --test repository
./dev/test/run.sh --test common
./dev/test/run.sh --test znuny-dev
./dev/test/run.sh --test instance-create   # real zd create tests
```

### Show help

```bash
./dev/test/run.sh --help
```

## Test Categories

### 1. Unit Tests

- Test individual functions in isolation
- Mock data and environments
- Edge cases and error handling

### 2. Integration Tests

- Test interaction between scripts
- End-to-end workflows
- Realistic scenarios

### 3. Regression Tests

- Ensure changes don't break existing functionality
- Automated tests on code changes

## Test Standards

- Each test should be isolated and repeatable
- Tests should have meaningful names
- Failed tests should provide clear error messages
- Tests should cover both positive and negative scenarios

## Verbose Mode

The `--verbose` flag provides additional debug information:

- File sizes, permissions, and modification times
- Command output and exit codes
- String lengths and content previews
- Parent directory contents on failures

See detailed examples:

```bash
# Standard output (compact)
./dev/test/run.sh

# Verbose output (detailed)
./dev/test/run.sh --verbose

# Verbose for specific test
./dev/test/run.sh -v -t instance
```

## Available Assertion Functions

The test framework provides various assertion functions in `utils/assertions.sh`:

- `assert_equal` - Check if two values are equal
- `assert_not_equal` - Check if two values are different
- `assert_success` - Verify command succeeds (exit code 0)
- `assert_failure` - Verify command fails (non-zero exit code)
- `assert_file_exists` - Check if file exists
- `assert_file_not_exists` - Check if file doesn't exist
- `assert_dir_exists` - Check if directory exists
- `assert_contains` - Check if string contains substring
- `assert_not_contains` - Check if string doesn't contain substring
- `assert_set` - Check if variable is set
- `assert_not_set` - Check if variable is not set

## Notes

- Tests use test data to avoid real system changes
- Temporary files are automatically cleaned up
- Tests can be integrated into CI/CD pipelines
- All tests are independent and can run in any order

## Development

### Adding New Tests

1. Create a new test file under `tests/`: e.g. `tests/<feature>.sh`
2. Set `TEST_DIR="$(cd "$(dirname "$0")/.." && pwd)"` (dev/test) and source the assertions: `source "$TEST_DIR/utils/assertions.sh"`
3. Write test functions
4. Call `print_test_summary` at the end
5. Add to test runner if needed

### Example Test Structure

```bash
#!/bin/bash

TEST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$TEST_DIR/utils/assertions.sh"

test_my_feature() {
    echo ""
    echo "Testing my feature..."

    local result=$(my_function)
    assert_equal "expected" "$result" "Should return expected value"
}

run_all_tests() {
    test_my_feature
    print_test_summary
}

run_all_tests
```
