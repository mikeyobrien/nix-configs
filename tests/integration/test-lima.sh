#!/usr/bin/env bash
# ABOUTME: Test Lima VM provisioning functionality for orchard host
# ABOUTME: Validates Lima installation, VM creation, and NixOS deployment

set -euo pipefail

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Test configuration
TEST_NAME="Lima VM Provisioning Tests"
VM_NAME="test-orchard"
LIMA_CONFIG="$ROOT_DIR/hosts/studio/lima-orchard.yaml"
PROVISION_SCRIPT="$ROOT_DIR/scripts/provision-orchard-vm.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

cleanup() {
    log_info "Cleaning up test resources..."
    if command -v limactl &> /dev/null; then
        if limactl list | grep -q "$VM_NAME"; then
            limactl stop "$VM_NAME" 2>/dev/null || true
            limactl delete "$VM_NAME" 2>/dev/null || true
        fi
    fi
}

trap cleanup EXIT

# Test functions
test_lima_installed() {
    log_info "Testing Lima installation..."
    
    if ! command -v limactl &> /dev/null; then
        log_error "Lima (limactl) is not installed"
        return 1
    fi
    
    local version=$(limactl --version 2>&1 | head -n1)
    log_info "Lima version: $version"
    
    return 0
}

test_lima_config_exists() {
    log_info "Testing Lima configuration file..."
    
    if [[ ! -f "$LIMA_CONFIG" ]]; then
        log_error "Lima configuration not found: $LIMA_CONFIG"
        return 1
    fi
    
    log_info "Lima configuration found at: $LIMA_CONFIG"
    return 0
}

test_provision_script_exists() {
    log_info "Testing provision script..."
    
    if [[ ! -f "$PROVISION_SCRIPT" ]]; then
        log_error "Provision script not found: $PROVISION_SCRIPT"
        return 1
    fi
    
    if [[ ! -x "$PROVISION_SCRIPT" ]]; then
        log_error "Provision script is not executable: $PROVISION_SCRIPT"
        return 1
    fi
    
    log_info "Provision script found and executable: $PROVISION_SCRIPT"
    return 0
}

test_dry_run_mode() {
    log_info "Testing provision script dry-run mode..."
    
    if [[ ! -f "$PROVISION_SCRIPT" ]]; then
        log_warning "Skipping dry-run test - provision script not found"
        return 0
    fi
    
    # Run provision script in dry-run mode
    if ! "$PROVISION_SCRIPT" --dry-run --vm-name "$VM_NAME" 2>&1 | grep -q "DRY RUN"; then
        log_error "Dry-run mode did not execute properly"
        return 1
    fi
    
    log_info "Dry-run mode works correctly"
    return 0
}

test_lima_vm_creation() {
    log_info "Testing Lima VM creation..."
    
    if [[ ! -f "$LIMA_CONFIG" ]]; then
        log_warning "Skipping VM creation test - Lima config not found"
        return 0
    fi
    
    # Create a test VM
    log_info "Creating test VM: $VM_NAME"
    if ! limactl start --name="$VM_NAME" "$LIMA_CONFIG" --tty=false; then
        log_error "Failed to create Lima VM"
        return 1
    fi
    
    # Wait for VM to be ready
    log_info "Waiting for VM to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if limactl list | grep -q "$VM_NAME.*Running"; then
            log_info "VM is running"
            break
        fi
        sleep 2
        ((attempt++))
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        log_error "VM did not start within timeout"
        return 1
    fi
    
    return 0
}

test_vm_connectivity() {
    log_info "Testing VM connectivity..."
    
    if ! limactl list | grep -q "$VM_NAME.*Running"; then
        log_warning "Skipping connectivity test - VM not running"
        return 0
    fi
    
    # Test SSH connectivity
    if ! limactl shell "$VM_NAME" true 2>/dev/null; then
        log_error "Cannot connect to VM via SSH"
        return 1
    fi
    
    log_info "SSH connectivity successful"
    
    # Test basic commands
    local os_info=$(limactl shell "$VM_NAME" cat /etc/os-release 2>/dev/null | grep "^ID=" | cut -d= -f2)
    log_info "VM OS: $os_info"
    
    return 0
}

test_nixos_compatibility() {
    log_info "Testing NixOS compatibility..."
    
    if ! limactl list | grep -q "$VM_NAME.*Running"; then
        log_warning "Skipping NixOS test - VM not running"
        return 0
    fi
    
    # Check if VM architecture matches expected (aarch64 for Mac Studio)
    local arch=$(limactl shell "$VM_NAME" uname -m 2>/dev/null)
    if [[ "$arch" != "aarch64" ]] && [[ "$arch" != "arm64" ]]; then
        log_error "Unexpected architecture: $arch (expected aarch64/arm64)"
        return 1
    fi
    
    log_info "VM architecture: $arch"
    
    # Check if NixOS can be installed (basic check)
    if ! limactl shell "$VM_NAME" which curl &>/dev/null; then
        log_error "curl not available in VM (required for NixOS installation)"
        return 1
    fi
    
    return 0
}

# Main test execution
main() {
    echo "====================================="
    echo "$TEST_NAME"
    echo "====================================="
    
    local failed=0
    local tests=(
        "test_lima_installed"
        "test_lima_config_exists"
        "test_provision_script_exists"
        "test_dry_run_mode"
        "test_lima_vm_creation"
        "test_vm_connectivity"
        "test_nixos_compatibility"
    )
    
    for test in "${tests[@]}"; do
        echo
        if $test; then
            log_info "✓ $test passed"
        else
            log_error "✗ $test failed"
            ((failed++))
        fi
    done
    
    echo
    echo "====================================="
    if [[ $failed -eq 0 ]]; then
        log_info "All tests passed!"
        return 0
    else
        log_error "$failed tests failed"
        return 1
    fi
}

# Run tests
main "$@"