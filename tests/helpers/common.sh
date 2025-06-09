#!/usr/bin/env bash
# ABOUTME: Common helper functions for all test scripts
# ABOUTME: Provides assertion functions, logging, and test utilities

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        return 1
    fi
}

assert_not_equals() {
    local unexpected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$unexpected" != "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        echo "  Value should not be: '$unexpected'"
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-Assertion failed}"
    
    if [[ "$condition" == "true" ]] || [[ "$condition" == "0" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "${RED}✗${NC} $message (expected true, got '$condition')"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Assertion failed}"
    
    if [[ "$condition" == "false" ]] || [[ "$condition" == "1" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "${RED}✗${NC} $message (expected false, got '$condition')"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $message: $file"
        return 0
    else
        echo -e "${RED}✗${NC} $message: $file"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist}"
    
    if [[ -d "$dir" ]]; then
        echo -e "${GREEN}✓${NC} $message: $dir"
        return 0
    else
        echo -e "${RED}✗${NC} $message: $dir"
        return 1
    fi
}

assert_command_exists() {
    local cmd="$1"
    local message="${2:-Command should exist}"
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $message: $cmd"
        return 0
    else
        echo -e "${RED}✗${NC} $message: $cmd"
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Exit code assertion}"
    
    if [[ "$expected" -eq "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $message (exit code: $expected)"
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        echo "  Expected exit code: $expected"
        echo "  Actual exit code:   $actual"
        return 1
    fi
}

# Test section helpers
begin_test_section() {
    local section_name="$1"
    echo ""
    echo -e "${BLUE}=== $section_name ===${NC}"
}

# Temporary file/directory helpers
create_temp_dir() {
    local prefix="${1:-test}"
    mktemp -d "/tmp/${prefix}.XXXXXX"
}

cleanup_temp() {
    local path="$1"
    if [[ -n "$path" ]] && [[ "$path" == /tmp/* ]]; then
        rm -rf "$path"
    fi
}

# Skip test helper
skip_test() {
    local reason="$1"
    echo -e "${YELLOW}⚠${NC} Test skipped: $reason"
    exit 0
}

# Check if running in CI
is_ci() {
    [[ "${CI:-false}" == "true" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${GITLAB_CI:-}" ]]
}

# Get timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Export functions so they're available to sourcing scripts
export -f assert_equals
export -f assert_not_equals
export -f assert_true
export -f assert_false
export -f assert_file_exists
export -f assert_dir_exists
export -f assert_command_exists
export -f assert_exit_code
export -f begin_test_section
export -f create_temp_dir
export -f cleanup_temp
export -f skip_test
export -f is_ci
export -f get_timestamp