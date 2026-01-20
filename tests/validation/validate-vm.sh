#!/usr/bin/env bash
# ABOUTME: Validate VM is properly configured and ready for k3s deployment
# ABOUTME: Checks SSH access, system specs, network config, and basic services

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# VM connection details
VM_HOST="${1:-}"
VM_USER="${VM_USER:-nixos}"
VM_PORT="${VM_PORT:-22}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"

# Expected specifications
MIN_CPU_CORES="${MIN_CPU_CORES:-2}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-4}"
MIN_DISK_GB="${MIN_DISK_GB:-20}"

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

Validate VM is properly configured and ready for deployment.

ARGUMENTS:
    vm-host             IP address or hostname of the VM to validate

OPTIONS:
    -u, --user USER     SSH user (default: $VM_USER)
    -p, --port PORT     SSH port (default: $VM_PORT)
    -k, --key KEY       SSH key path (default: $SSH_KEY)
    --min-cores N       Minimum CPU cores (default: $MIN_CPU_CORES)
    --min-memory GB     Minimum memory in GB (default: $MIN_MEMORY_GB)
    --min-disk GB       Minimum disk space in GB (default: $MIN_DISK_GB)
    -h, --help          Show this help message

ENVIRONMENT:
    VM_USER             SSH user for VM connection
    VM_PORT             SSH port for VM connection
    SSH_KEY             Path to SSH private key

EXAMPLES:
    # Validate VM at specific IP
    $0 10.10.20.12

    # Validate with custom user
    $0 10.10.20.12 --user root

    # Validate with higher requirements
    $0 10.10.20.12 --min-cores 4 --min-memory 8

EOF
}

# Parse command line arguments
parse_args() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    # Check for help flag first
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        usage
        exit 0
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
            --min-cores)
                MIN_CPU_CORES="$2"
                shift 2
                ;;
            --min-memory)
                MIN_MEMORY_GB="$2"
                shift 2
                ;;
            --min-disk)
                MIN_DISK_GB="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
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
test_ssh_connectivity() {
    local test_name="SSH connectivity"
    test_start "$test_name"
    
    if ssh_cmd "true"; then
        test_pass "$test_name"
        return 0
    else
        test_fail "$test_name" "Cannot connect via SSH"
        return 1
    fi
}

test_operating_system() {
    local test_name="Operating system"
    test_start "$test_name"
    
    local os_info
    if ! os_info=$(ssh_cmd "cat /etc/os-release"); then
        test_fail "$test_name" "Cannot read OS information"
        return 1
    fi
    
    if echo "$os_info" | grep -q "ID=nixos"; then
        local version=$(echo "$os_info" | grep "VERSION_ID" | cut -d= -f2 | tr -d '"')
        test_pass "$test_name (NixOS $version)"
    elif echo "$os_info" | grep -qi "ubuntu\|debian"; then
        log_warning "VM is not running NixOS, will need installation"
        test_pass "$test_name (Non-NixOS, installation required)"
    else
        test_fail "$test_name" "Unknown operating system"
        return 1
    fi
    
    return 0
}

test_cpu_cores() {
    local test_name="CPU cores"
    test_start "$test_name"
    
    local cpu_count
    if ! cpu_count=$(ssh_cmd "nproc"); then
        test_fail "$test_name" "Cannot determine CPU count"
        return 1
    fi
    
    if [[ $cpu_count -ge $MIN_CPU_CORES ]]; then
        test_pass "$test_name ($cpu_count cores)"
    else
        test_fail "$test_name" "Insufficient CPU cores: $cpu_count < $MIN_CPU_CORES"
        return 1
    fi
    
    return 0
}

test_memory() {
    local test_name="Memory"
    test_start "$test_name"
    
    local memory_kb
    if ! memory_kb=$(ssh_cmd "grep MemTotal /proc/meminfo | awk '{print \$2}'"); then
        test_fail "$test_name" "Cannot determine memory size"
        return 1
    fi
    
    local memory_gb=$((memory_kb / 1024 / 1024))
    if [[ $memory_gb -ge $MIN_MEMORY_GB ]]; then
        test_pass "$test_name (${memory_gb}GB)"
    else
        test_fail "$test_name" "Insufficient memory: ${memory_gb}GB < ${MIN_MEMORY_GB}GB"
        return 1
    fi
    
    return 0
}

test_disk_space() {
    local test_name="Disk space"
    test_start "$test_name"
    
    local disk_size
    if ! disk_size=$(ssh_cmd "df -BG / | tail -1 | awk '{print \$2}' | tr -d 'G'"); then
        test_fail "$test_name" "Cannot determine disk size"
        return 1
    fi
    
    if [[ $disk_size -ge $MIN_DISK_GB ]]; then
        test_pass "$test_name (${disk_size}GB)"
    else
        test_fail "$test_name" "Insufficient disk space: ${disk_size}GB < ${MIN_DISK_GB}GB"
        return 1
    fi
    
    return 0
}

test_network_connectivity() {
    local test_name="Network connectivity"
    test_start "$test_name"
    
    # Test internet connectivity
    if ssh_cmd "ping -c 1 -W 2 8.8.8.8" >/dev/null; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "No internet connectivity"
        return 1
    fi
    
    return 0
}

test_hostname_resolution() {
    local test_name="Hostname resolution"
    test_start "$test_name"
    
    # Test DNS resolution
    if ssh_cmd "nslookup github.com" >/dev/null || ssh_cmd "host github.com" >/dev/null; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "DNS resolution not working"
        return 1
    fi
    
    return 0
}

test_time_sync() {
    local test_name="Time synchronization"
    test_start "$test_name"
    
    # Check if time is reasonably synchronized
    local vm_time
    local local_time
    
    if ! vm_time=$(ssh_cmd "date +%s"); then
        test_fail "$test_name" "Cannot get VM time"
        return 1
    fi
    
    local_time=$(date +%s)
    local time_diff=$((local_time - vm_time))
    time_diff=${time_diff#-}  # Absolute value
    
    if [[ $time_diff -lt 60 ]]; then
        test_pass "$test_name (drift: ${time_diff}s)"
    else
        test_fail "$test_name" "Time drift too large: ${time_diff}s"
        return 1
    fi
    
    return 0
}

test_kernel_modules() {
    local test_name="Kernel modules for k3s"
    test_start "$test_name"
    
    # Check for required kernel modules
    local required_modules=("br_netfilter" "overlay")
    local missing_modules=()
    
    for module in "${required_modules[@]}"; do
        if ! ssh_cmd "lsmod | grep -q '^$module' || modprobe -n $module 2>/dev/null"; then
            missing_modules+=("$module")
        fi
    done
    
    if [[ ${#missing_modules[@]} -eq 0 ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Missing modules: ${missing_modules[*]}"
        return 1
    fi
    
    return 0
}

test_firewall_ports() {
    local test_name="Firewall configuration"
    test_start "$test_name"
    
    # For k3s, we need certain ports open
    # This is a basic check - actual firewall rules depend on the setup
    
    # Check if common firewall tools exist
    if ssh_cmd "command -v iptables" >/dev/null; then
        log_info "iptables is available"
        test_pass "$test_name"
    elif ssh_cmd "command -v nft" >/dev/null; then
        log_info "nftables is available"
        test_pass "$test_name"
    else
        log_warning "No firewall tools found"
        test_pass "$test_name (no firewall detected)"
    fi
    
    return 0
}

test_selinux_status() {
    local test_name="SELinux status"
    test_start "$test_name"
    
    # Check SELinux status (k3s works better with SELinux disabled or permissive)
    if ssh_cmd "command -v getenforce" >/dev/null; then
        local selinux_status
        selinux_status=$(ssh_cmd "getenforce" || echo "Unknown")
        
        case "$selinux_status" in
            "Disabled"|"Permissive")
                test_pass "$test_name ($selinux_status)"
                ;;
            "Enforcing")
                log_warning "SELinux is enforcing, may need configuration for k3s"
                test_pass "$test_name ($selinux_status - needs config)"
                ;;
            *)
                test_fail "$test_name" "Unknown SELinux status: $selinux_status"
                return 1
                ;;
        esac
    else
        test_pass "$test_name (not installed)"
    fi
    
    return 0
}

# Summary report
print_summary() {
    echo
    echo "====================================="
    echo "VM Validation Summary"
    echo "====================================="
    echo "Host: $VM_HOST"
    echo "Total tests: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo "====================================="
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_info "VM validation successful! VM is ready for deployment."
        return 0
    else
        log_error "VM validation failed. Please fix the issues above."
        return 1
    fi
}

# Main execution
main() {
    parse_args "$@"
    
    echo "====================================="
    echo "VM Validation for $VM_HOST"
    echo "====================================="
    
    # Run all validation tests
    local tests=(
        "test_ssh_connectivity"
        "test_operating_system"
        "test_cpu_cores"
        "test_memory"
        "test_disk_space"
        "test_network_connectivity"
        "test_hostname_resolution"
        "test_time_sync"
        "test_kernel_modules"
        "test_firewall_ports"
        "test_selinux_status"
    )
    
    for test in "${tests[@]}"; do
        $test || true  # Continue even if test fails
    done
    
    # Print summary and exit with appropriate code
    print_summary
}

# Run main function
main "$@"