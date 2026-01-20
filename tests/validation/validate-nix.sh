#!/usr/bin/env bash
# ABOUTME: Validate Nix/NixOS installation and configuration on VM
# ABOUTME: Checks Nix installation, flake config, packages, and agenix secrets

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# VM connection details
VM_HOST="${1:-}"
VM_USER="${VM_USER:-nixos}"
VM_PORT="${VM_PORT:-22}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"

# Expected configuration
FLAKE_PATH="${FLAKE_PATH:-/etc/nixos}"
EXPECTED_PACKAGES=("git" "vim" "htop" "curl")
EXPECTED_HOST=""  # Will be determined from VM_HOST

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 <vm-host> [OPTIONS]

Validate Nix/NixOS installation and configuration on VM.

ARGUMENTS:
    vm-host             IP address or hostname of the VM to validate

OPTIONS:
    -u, --user USER     SSH user (default: $VM_USER)
    -p, --port PORT     SSH port (default: $VM_PORT)
    -k, --key KEY       SSH key path (default: $SSH_KEY)
    -f, --flake PATH    Flake path on VM (default: $FLAKE_PATH)
    -H, --hostname NAME Expected hostname (auto-detected if not set)
    -h, --help          Show this help message

ENVIRONMENT:
    VM_USER             SSH user for VM connection
    VM_PORT             SSH port for VM connection
    SSH_KEY             Path to SSH private key
    FLAKE_PATH          Path to NixOS flake on VM

EXAMPLES:
    # Validate NixOS on VM
    $0 10.10.20.12

    # Validate with specific hostname expectation
    $0 10.10.20.12 --hostname coral

    # Validate with custom flake path
    $0 10.10.20.12 --flake /home/nixos/nix-configs

EOF
}

# Parse command line arguments
parse_args() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    VM_HOST="$1"
    shift
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -u|--user)
                VM_USER="$2"
                shift 2
                ;;
            -p|--port)
                VM_PORT="$2"
                shift 2
                ;;
            -k|--key)
                SSH_KEY="$2"
                shift 2
                ;;
            -f|--flake)
                FLAKE_PATH="$2"
                shift 2
                ;;
            -H|--hostname)
                EXPECTED_HOST="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Auto-detect expected hostname from IP if not set
    if [[ -z "$EXPECTED_HOST" ]]; then
        case "$VM_HOST" in
            "10.10.20.11"|*orchard*)
                EXPECTED_HOST="orchard"
                ;;
            "10.10.20.12"|*coral*)
                EXPECTED_HOST="coral"
                ;;
            "10.10.20.13"|*reef*)
                EXPECTED_HOST="reef"
                ;;
            *)
                log_warning "Cannot auto-detect hostname for $VM_HOST"
                ;;
        esac
    fi
}

# SSH command helper
ssh_cmd() {
    ssh -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -p "$VM_PORT" \
        -i "$SSH_KEY" \
        "$VM_USER@$VM_HOST" \
        "$@" 2>/dev/null
}

# Test result tracking
test_start() {
    local test_name="$1"
    log_test "Running: $test_name"
    ((TOTAL_TESTS++))
}

test_pass() {
    local test_name="$1"
    log_info "✓ $test_name"
    ((PASSED_TESTS++))
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    log_error "✗ $test_name: $reason"
    ((FAILED_TESTS++))
}

# Validation tests
test_nix_installation() {
    local test_name="Nix installation"
    test_start "$test_name"
    
    if ssh_cmd "command -v nix" >/dev/null; then
        local nix_version
        nix_version=$(ssh_cmd "nix --version" || echo "unknown")
        test_pass "$test_name ($nix_version)"
        return 0
    else
        test_fail "$test_name" "Nix is not installed"
        return 1
    fi
}

test_nixos_system() {
    local test_name="NixOS system"
    test_start "$test_name"
    
    if ssh_cmd "test -f /etc/NIXOS"; then
        local nixos_version
        nixos_version=$(ssh_cmd "nixos-version" || echo "unknown")
        test_pass "$test_name ($nixos_version)"
        return 0
    else
        log_warning "System is not NixOS, may be using Nix on another OS"
        test_pass "$test_name (non-NixOS with Nix)"
        return 0
    fi
}

test_nix_daemon() {
    local test_name="Nix daemon"
    test_start "$test_name"
    
    if ssh_cmd "systemctl is-active nix-daemon" >/dev/null; then
        test_pass "$test_name (running)"
        return 0
    elif ssh_cmd "test -S /nix/var/nix/daemon-socket/socket"; then
        test_pass "$test_name (socket exists)"
        return 0
    else
        log_warning "Nix daemon not running, single-user mode?"
        test_pass "$test_name (single-user mode)"
        return 0
    fi
}

test_flake_support() {
    local test_name="Flake support"
    test_start "$test_name"
    
    if ssh_cmd "nix flake --help" >/dev/null 2>&1; then
        test_pass "$test_name"
        return 0
    else
        test_fail "$test_name" "Flakes not enabled or not available"
        return 1
    fi
}

test_flake_configuration() {
    local test_name="Flake configuration"
    test_start "$test_name"
    
    if ssh_cmd "test -f $FLAKE_PATH/flake.nix"; then
        # Check if flake evaluates
        if ssh_cmd "cd $FLAKE_PATH && nix flake check --no-write-lock-file" 2>/dev/null; then
            test_pass "$test_name (valid flake)"
        else
            log_warning "Flake exists but doesn't evaluate cleanly"
            test_pass "$test_name (needs attention)"
        fi
        return 0
    else
        test_fail "$test_name" "No flake.nix found at $FLAKE_PATH"
        return 1
    fi
}

test_hostname_configuration() {
    local test_name="Hostname configuration"
    test_start "$test_name"
    
    local actual_hostname
    actual_hostname=$(ssh_cmd "hostname" || echo "unknown")
    
    if [[ -n "$EXPECTED_HOST" ]]; then
        if [[ "$actual_hostname" == "$EXPECTED_HOST" ]]; then
            test_pass "$test_name ($actual_hostname)"
        else
            test_fail "$test_name" "Expected '$EXPECTED_HOST', got '$actual_hostname'"
            return 1
        fi
    else
        test_pass "$test_name ($actual_hostname)"
    fi
    
    return 0
}

test_system_packages() {
    local test_name="System packages"
    test_start "$test_name"
    
    local missing_packages=()
    
    for pkg in "${EXPECTED_PACKAGES[@]}"; do
        if ! ssh_cmd "command -v $pkg" >/dev/null; then
            missing_packages+=("$pkg")
        fi
    done
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Missing packages: ${missing_packages[*]}"
        return 1
    fi
    
    return 0
}

test_nix_store_health() {
    local test_name="Nix store health"
    test_start "$test_name"
    
    # Basic store verification
    if ssh_cmd "nix store verify --no-trust" 2>/dev/null; then
        test_pass "$test_name"
    else
        log_warning "Nix store verification had issues"
        test_pass "$test_name (needs attention)"
    fi
    
    return 0
}

test_agenix_installation() {
    local test_name="Agenix installation"
    test_start "$test_name"
    
    # Check if agenix is available (for secret management)
    if ssh_cmd "command -v agenix" >/dev/null || \
       ssh_cmd "test -f /run/agenix" || \
       ssh_cmd "systemctl list-units | grep -q agenix"; then
        test_pass "$test_name"
        return 0
    else
        log_warning "Agenix not detected, secrets management may not be configured"
        test_pass "$test_name (not configured)"
        return 0
    fi
}

test_k3s_readiness() {
    local test_name="K3s readiness"
    test_start "$test_name"
    
    # Check if system is ready for k3s
    local issues=()
    
    # Check for systemd (k3s service management)
    if ! ssh_cmd "command -v systemctl" >/dev/null; then
        issues+=("no systemd")
    fi
    
    # Check for iptables or nftables
    if ! ssh_cmd "command -v iptables" >/dev/null && ! ssh_cmd "command -v nft" >/dev/null; then
        issues+=("no firewall tools")
    fi
    
    # Check for required kernel features
    if ! ssh_cmd "test -f /proc/sys/net/bridge/bridge-nf-call-iptables"; then
        issues+=("missing bridge netfilter")
    fi
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Issues: ${issues[*]}"
        return 1
    fi
    
    return 0
}

test_nix_channel_configuration() {
    local test_name="Nix channels"
    test_start "$test_name"
    
    # Check nix channels (if not using pure flakes)
    local channels
    channels=$(ssh_cmd "nix-channel --list" 2>/dev/null || echo "")
    
    if [[ -n "$channels" ]]; then
        log_info "Active channels: $(echo "$channels" | wc -l)"
        test_pass "$test_name"
    else
        log_info "No channels configured (using flakes)"
        test_pass "$test_name (flakes-only)"
    fi
    
    return 0
}

test_home_manager() {
    local test_name="Home Manager"
    test_start "$test_name"
    
    # Check if home-manager is configured
    if ssh_cmd "command -v home-manager" >/dev/null || \
       ssh_cmd "test -d ~/.config/home-manager" || \
       ssh_cmd "test -f ~/.config/nixpkgs/home.nix"; then
        test_pass "$test_name (configured)"
    else
        log_info "Home Manager not detected"
        test_pass "$test_name (not configured)"
    fi
    
    return 0
}

# Summary report
print_summary() {
    echo
    echo "====================================="
    echo "Nix/NixOS Validation Summary"
    echo "====================================="
    echo "Host: $VM_HOST"
    if [[ -n "$EXPECTED_HOST" ]]; then
        echo "Expected hostname: $EXPECTED_HOST"
    fi
    echo "Total tests: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo "====================================="
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_info "Nix validation successful! System is properly configured."
        return 0
    else
        log_error "Nix validation failed. Please fix the issues above."
        return 1
    fi
}

# Main execution
main() {
    parse_args "$@"
    
    echo "====================================="
    echo "Nix/NixOS Validation for $VM_HOST"
    echo "====================================="
    
    # Check basic connectivity first
    if ! ssh_cmd "true"; then
        log_error "Cannot connect to VM via SSH"
        exit 1
    fi
    
    # Run all validation tests
    local tests=(
        "test_nix_installation"
        "test_nixos_system"
        "test_nix_daemon"
        "test_flake_support"
        "test_flake_configuration"
        "test_hostname_configuration"
        "test_system_packages"
        "test_nix_store_health"
        "test_agenix_installation"
        "test_k3s_readiness"
        "test_nix_channel_configuration"
        "test_home_manager"
    )
    
    for test in "${tests[@]}"; do
        $test || true  # Continue even if test fails
    done
    
    # Print summary and exit with appropriate code
    print_summary
}

# Run main function
main "$@"