# K3s HA Cluster Tests

This directory contains the comprehensive test suite for the k3s HA cluster expansion project.

## Directory Structure

- `unit/` - Unit tests for individual components
- `integration/` - Integration tests for component interactions
- `validation/` - VM and configuration validation tests
- `health/` - Cluster health check tests
- `monitoring/` - Monitoring and metrics tests
- `rollback/` - Rollback procedure tests
- `e2e/` - End-to-end deployment tests
- `helpers/` - Common test utilities and helper functions

## Running Tests

### Run all tests:
```bash
./tests/run-all.sh
```

### Run with verbose output:
```bash
./tests/run-all.sh -v
```

### Run individual test:
```bash
./tests/unit/test-framework-example.sh
```

## Writing Tests

1. Create test files with names starting with `test-` or ending with `_test.sh`
2. Make test files executable: `chmod +x test-name.sh`
3. Source the common helpers: `source "$SCRIPT_DIR/../helpers/common.sh"`
4. Use assertion functions from `helpers/common.sh`

### Example Test Structure

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

echo "Running: My Test"

begin_test_section "Test Section"

assert_equals "expected" "actual" "Test description"
assert_file_exists "/path/to/file" "File should exist"

echo "All tests passed!"
exit 0
```

## Test Helpers

Available assertion functions:
- `assert_equals` - Test string equality
- `assert_not_equals` - Test string inequality
- `assert_true` - Test boolean true
- `assert_false` - Test boolean false
- `assert_file_exists` - Test file existence
- `assert_dir_exists` - Test directory existence
- `assert_command_exists` - Test command availability
- `assert_exit_code` - Test command exit codes

Other helpers:
- `begin_test_section` - Start a new test section
- `create_temp_dir` - Create temporary directory
- `cleanup_temp` - Clean up temporary files
- `skip_test` - Skip test with reason
- `is_ci` - Check if running in CI

## Exit Codes

- `0` - All tests passed
- `1` - One or more tests failed
- Other codes indicate specific errors