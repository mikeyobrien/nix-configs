#!/usr/bin/env bash
# ABOUTME: Wait for VM to become accessible via SSH with configurable timeout
# ABOUTME: Provides status updates and supports multiple VM types (Lima, Proxmox)

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default settings
VM_HOST="${1:-}"
VM_USER="${VM_USER:-nixos}"
VM_PORT="${VM_PORT:-22}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
TIMEOUT="${TIMEOUT:-300}"  # 5 minutes default
INTERVAL="${INTERVAL:-5}"  # Check every 5 seconds
QUIET="${QUIET:-false}"
VM_TYPE=""  # auto-detect

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${GREEN}[INFO]${NC} $1"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $1"
    fi
}

log_status() {
    if [[ "$QUIET" != "true" ]]; then
        echo -ne "${BLUE}[STATUS]${NC} $1\r"
    fi
}

usage() {
    cat << EOF
Usage: $0 <vm-host|vm-name> [OPTIONS]

Wait for VM to become accessible via SSH.

ARGUMENTS:
    vm-host/vm-name     IP address, hostname, or VM name to wait for

OPTIONS:
    -u, --user USER     SSH user (default: $VM_USER)
    -p, --port PORT     SSH port (default: $VM_PORT)
    -k, --key KEY       SSH key path (default: $SSH_KEY)
    -t, --timeout SEC   Timeout in seconds (default: $TIMEOUT)
    -i, --interval SEC  Check interval in seconds (default: $INTERVAL)
    -q, --quiet         Suppress status messages
    --type TYPE         VM type: lima, proxmox, ssh (auto-detected)
    -h, --help          Show this help message

ENVIRONMENT:
    VM_USER             SSH user for VM connection
    VM_PORT             SSH port for VM connection
    SSH_KEY             Path to SSH private key
    TIMEOUT             Maximum wait time in seconds
    INTERVAL            Check interval in seconds

EXAMPLES:
    # Wait for VM by IP
    $0 10.10.20.12

    # Wait for Lima VM by name
    $0 orchard --type lima

    # Wait with custom timeout
    $0 10.10.20.12 --timeout 600

    # Quiet mode for scripts
    $0 10.10.20.12 --quiet

EXIT CODES:
    0   VM is accessible
    1   Timeout reached
    2   Invalid arguments
    3   VM type specific error

EOF
}

# Parse command line arguments
parse_args() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 2
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
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -i|--interval)
                INTERVAL="$2"
                shift 2
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            --type)
                VM_TYPE="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 2
                ;;
        esac
    done
}

# Auto-detect VM type
detect_vm_type() {
    if [[ -n "$VM_TYPE" ]]; then
        return 0
    fi
    
    # Check if it's an IP address
    if [[ "$VM_HOST" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        VM_TYPE="ssh"
        return 0
    fi
    
    # Check if it's a Lima VM
    if command -v limactl &> /dev/null && limactl list 2>/dev/null | grep -q "^${VM_HOST}\s"; then
        VM_TYPE="lima"
        return 0
    fi
    
    # Check if it looks like a hostname
    if [[ "$VM_HOST" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        VM_TYPE="ssh"
        return 0
    fi
    
    # Default to SSH
    VM_TYPE="ssh"
}

# Get VM connection info based on type
get_vm_connection_info() {
    case "$VM_TYPE" in
        lima)
            # For Lima VMs, we need to check if it's running first
            if ! limactl list | grep -q "^${VM_HOST}\s.*Running"; then
                log_error "Lima VM '$VM_HOST' is not running"
                log_info "Start it with: limactl start $VM_HOST"
                exit 3
            fi
            
            # Lima handles SSH connection differently
            # We'll use lima's built-in SSH
            ;;
        proxmox)
            # For Proxmox, VM_HOST should be an IP or hostname
            # Could extend to support VM ID lookup via Proxmox API
            ;;
        ssh|*)
            # Direct SSH connection
            ;;
    esac
}

# Test SSH connectivity
test_ssh_connection() {
    case "$VM_TYPE" in
        lima)
            limactl shell "$VM_HOST" true 2>/dev/null
            ;;
        *)
            ssh -o ConnectTimeout=5 \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o PasswordAuthentication=no \
                -o BatchMode=yes \
                -p "$VM_PORT" \
                -i "$SSH_KEY" \
                "$VM_USER@$VM_HOST" \
                true 2>/dev/null
            ;;
    esac
}

# Wait for VM with progress indication
wait_for_vm() {
    local start_time=$(date +%s)
    local end_time=$((start_time + TIMEOUT))
    local attempt=0
    
    log_info "Waiting for VM to become accessible..."
    log_info "VM: $VM_HOST (type: $VM_TYPE)"
    log_info "Timeout: ${TIMEOUT}s, Check interval: ${INTERVAL}s"
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local remaining=$((end_time - current_time))
        
        # Check if timeout reached
        if [[ $current_time -ge $end_time ]]; then
            echo  # Clear the status line
            log_error "Timeout reached after ${TIMEOUT}s"
            return 1
        fi
        
        # Update status
        ((attempt++))
        log_status "Attempt $attempt, elapsed: ${elapsed}s, remaining: ${remaining}s"
        
        # Test connection
        if test_ssh_connection; then
            echo  # Clear the status line
            log_info "✓ VM is accessible after ${elapsed}s"
            
            # Additional validation if not quiet
            if [[ "$QUIET" != "true" ]]; then
                case "$VM_TYPE" in
                    lima)
                        log_info "Connect with: limactl shell $VM_HOST"
                        ;;
                    *)
                        log_info "Connect with: ssh -p $VM_PORT $VM_USER@$VM_HOST"
                        ;;
                esac
            fi
            
            return 0
        fi
        
        # Wait before next attempt
        sleep "$INTERVAL"
    done
}

# Validate prerequisites
check_prerequisites() {
    # Check SSH key exists
    if [[ ! -f "$SSH_KEY" ]] && [[ "$VM_TYPE" != "lima" ]]; then
        log_error "SSH key not found: $SSH_KEY"
        return 1
    fi
    
    # Check for required commands based on VM type
    case "$VM_TYPE" in
        lima)
            if ! command -v limactl &> /dev/null; then
                log_error "Lima (limactl) is not installed"
                return 1
            fi
            ;;
        *)
            if ! command -v ssh &> /dev/null; then
                log_error "SSH client is not installed"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Main execution
main() {
    # Check for help flag first
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi
    
    parse_args "$@"
    
    # Detect VM type
    detect_vm_type
    
    # Get VM connection info
    get_vm_connection_info
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 3
    fi
    
    # Wait for VM
    if wait_for_vm; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"