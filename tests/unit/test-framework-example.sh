#!/usr/bin/env bash
# ABOUTME: Example test to verify the test framework is working correctly
# ABOUTME: This test always passes and demonstrates the test structure

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"

# Source test helpers
source "$SCRIPT_DIR/../helpers/common.sh"

# Test name
TEST_NAME="Framework Example Test"

echo "Running: $TEST_NAME"

begin_test_section "Project Structure Tests"

# Test 1: Verify we can access the project root
assert_dir_exists "$PROJECT_ROOT" "Project root directory exists"

# Test 2: Verify flake.nix exists
assert_file_exists "$PROJECT_ROOT/flake.nix" "Found flake.nix in project root"

# Test 3: Verify test directory structure
begin_test_section "Test Directory Structure"

test_dirs=("unit" "integration" "helpers" "validation" "health" "monitoring" "rollback" "e2e")
for dir in "${test_dirs[@]}"; do
    assert_dir_exists "$SCRIPT_DIR/../$dir" "Test directory exists: $dir"
done

# Test 4: Test assertion helpers
begin_test_section "Assertion Helper Tests"

assert_equals "test" "test" "String equality assertion"
assert_not_equals "foo" "bar" "String inequality assertion"
assert_true "true" "Boolean true assertion"
assert_false "false" "Boolean false assertion"

# Test 5: Command existence
begin_test_section "Command Availability Tests"

assert_command_exists "bash" "Bash is available"
assert_command_exists "git" "Git is available"

echo ""
echo "All tests in $TEST_NAME passed!"
exit 0