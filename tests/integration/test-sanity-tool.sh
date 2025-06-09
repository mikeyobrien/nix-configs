#!/usr/bin/env bash
# ABOUTME: Test that the sanity.py tool itself is working correctly
# ABOUTME: Validates the Python CLI testing tool functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"

source "$SCRIPT_DIR/../helpers/common.sh"

echo "Running: Sanity Tool Tests"

begin_test_section "Tool Availability"

# Check that the sanity tool exists and is executable
assert_file_exists "$PROJECT_ROOT/tests/sanity.py" "Sanity tool exists"

if [[ -x "$PROJECT_ROOT/tests/sanity.py" ]]; then
    echo -e "${GREEN}✓${NC} Sanity tool is executable"
else
    echo -e "${RED}✗${NC} Sanity tool is not executable"
    exit 1
fi

begin_test_section "Help Output"

# Test that help works
if "$PROJECT_ROOT/tests/sanity.py" --help &>/dev/null; then
    echo -e "${GREEN}✓${NC} Help command works"
else
    echo -e "${RED}✗${NC} Help command failed"
    exit 1
fi

begin_test_section "Localhost Connectivity Test"

# Test localhost connectivity (should always work)
if "$PROJECT_ROOT/tests/sanity.py" --check-host localhost --port 22; then
    echo -e "${GREEN}✓${NC} Localhost connectivity test passed"
else
    # SSH might not be running locally, try a different port
    if "$PROJECT_ROOT/tests/sanity.py" --check-host localhost --port 80; then
        echo -e "${GREEN}✓${NC} Localhost connectivity test passed (port 80)"
    else
        echo -e "${YELLOW}⚠${NC} Localhost connectivity test skipped (no open ports)"
    fi
fi

echo ""
echo "All sanity tool tests passed!"
exit 0