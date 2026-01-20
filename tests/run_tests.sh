#!/usr/bin/env bash
# ABOUTME: Shell wrapper for running NixTest-based tests with colored output
# ABOUTME: Provides easy command-line interface to the Nix test runner

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

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

# Function to run tests and format output
run_tests() {
    local test_file="$SCRIPT_DIR/run_tests.nix"
    
    log_info "Running NixTest-based test suites..."
    echo
    
    # Run the Nix test runner
    if ! nix eval --impure --file "$test_file" success; then
        log_error "Test evaluation failed!"
        return 1
    fi
    
    local success
    success=$(nix eval --impure --file "$test_file" success)
    
    if [[ "$success" == "true" ]]; then
        log_success "All tests passed!"
        
        # Display summary
        local summary
        summary=$(nix eval --impure --file "$test_file" summary --raw)
        echo "📊 $summary"
        
        return 0
    else
        log_error "Some tests failed!"
        
        # Display detailed report
        echo
        log_info "Generating detailed test report..."
        nix eval --impure --file "$test_file" report --raw
        
        return 1
    fi
}

# Function to run individual test file
run_single_test() {
    local test_file="$1"
    
    if [[ ! -f "$test_file" ]]; then
        log_error "Test file not found: $test_file"
        return 1
    fi
    
    log_info "Running single test file: $(basename "$test_file")"
    
    # Import the test file and run it
    local test_expr="let nixtest = import ./nixtest.nix; tests = import $test_file; in nixtest.runTests tests"
    
    if nix eval --impure --expr "$test_expr" --file /dev/stdin > /dev/null <<< ""; then
        log_success "Test file passed: $(basename "$test_file")"
        return 0
    else
        log_error "Test file failed: $(basename "$test_file")"
        return 1
    fi
}

# Function to show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [TEST_FILE]

Run NixTest-based test suites for Nix configurations.

Options:
  -h, --help      Show this help message
  -v, --verbose   Enable verbose output
  -s, --summary   Show only test summary
  -r, --report    Show detailed test report

Arguments:
  TEST_FILE       Run a single test file instead of all tests

Examples:
  $0                                    # Run all test suites
  $0 unit/base_vm_test.nix             # Run specific test file
  $0 --summary                         # Show summary only
  $0 --report                          # Show detailed report

EOF
}

# Parse command line arguments
VERBOSE=false
SUMMARY_ONLY=false
REPORT_ONLY=false
TEST_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -s|--summary)
            SUMMARY_ONLY=true
            shift
            ;;
        -r|--report)
            REPORT_ONLY=true
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            TEST_FILE="$1"
            shift
            ;;
    esac
done

# Change to script directory
cd "$SCRIPT_DIR"

# Handle different modes
if [[ -n "$TEST_FILE" ]]; then
    # Run single test file
    run_single_test "$TEST_FILE"
    exit $?
elif [[ "$SUMMARY_ONLY" == "true" ]]; then
    # Show summary only
    summary=$(nix eval --impure --file run_tests.nix summary --raw)
    echo "$summary"
    exit 0
elif [[ "$REPORT_ONLY" == "true" ]]; then
    # Show detailed report
    nix eval --impure --file run_tests.nix report --raw
    exit 0
else
    # Run all tests
    run_tests
    exit $?
fi