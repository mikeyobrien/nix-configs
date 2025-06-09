#!/usr/bin/env bash
# ABOUTME: Main test runner that executes all test suites for the k3s HA cluster setup
# ABOUTME: Provides comprehensive test execution with proper error handling and reporting

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." &> /dev/null && pwd)"

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to run a test file
run_test() {
    local test_file="$1"
    local test_name="$(basename "$test_file")"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    log_info "Running $test_name..."
    
    if [[ -x "$test_file" ]]; then
        if "$test_file"; then
            log_success "$test_name"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            log_error "$test_name (exit code: $?)"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    else
        log_warning "$test_name is not executable, skipping"
        return 0
    fi
}

# Function to run all tests in a directory
run_test_suite() {
    local suite_name="$1"
    local suite_dir="$2"
    
    if [[ ! -d "$suite_dir" ]]; then
        log_warning "Test suite directory $suite_dir does not exist, skipping"
        return 0
    fi
    
    local test_files=($(find "$suite_dir" -name "test-*.sh" -o -name "*_test.sh" 2>/dev/null | sort))
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_info "No tests found in $suite_name suite"
        return 0
    fi
    
    echo
    log_info "=== Running $suite_name Tests ==="
    
    for test_file in "${test_files[@]}"; do
        run_test "$test_file" || true  # Continue on failure
    done
}

# Main test execution
main() {
    log_info "Starting test execution from $PROJECT_ROOT"
    log_info "Test directory: $SCRIPT_DIR"
    echo
    
    # Check if we're in a git repo and on the right branch
    if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
        local current_branch=$(git branch --show-current)
        log_info "Current git branch: $current_branch"
    fi
    
    # Run each test suite
    run_test_suite "Unit" "$SCRIPT_DIR/unit"
    run_test_suite "Integration" "$SCRIPT_DIR/integration"
    run_test_suite "Validation" "$SCRIPT_DIR/validation"
    run_test_suite "Health" "$SCRIPT_DIR/health"
    run_test_suite "Monitoring" "$SCRIPT_DIR/monitoring"
    run_test_suite "Rollback" "$SCRIPT_DIR/rollback"
    run_test_suite "End-to-End" "$SCRIPT_DIR/e2e"
    
    # Summary
    echo
    echo "========================================"
    log_info "Test Summary"
    echo "========================================"
    echo "Total tests run: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo
        log_success "All tests passed! ✨"
        exit 0
    else
        echo
        log_error "Some tests failed. Please check the output above."
        exit 1
    fi
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -h, --help     Show this help message"
            echo "  -v, --verbose  Enable verbose output"
            echo ""
            echo "This script runs all test suites for the k3s HA cluster setup."
            exit 0
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main