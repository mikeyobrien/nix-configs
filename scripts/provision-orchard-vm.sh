#!/usr/bin/env bash
# ABOUTME: Provision orchard VM using Lima for k3s cluster on Mac Studio
# ABOUTME: Supports dry-run mode, VM lifecycle management, and NixOS installation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIMA_CONFIG="$ROOT_DIR/hosts/studio/lima-orchard.yaml"
VM_NAME="orchard"
DEFAULT_NIXOS_VERSION="24.05"

# Runtime options
DRY_RUN=false
INSTALL_NIXOS=false
DESTROY_EXISTING=false
VERBOSE=false

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

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

dry_run_msg() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would execute: $1"
    fi
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Provision orchard VM for k3s cluster on Mac Studio using Lima.

OPTIONS:
    -h, --help              Show this help message
    -d, --dry-run           Show what would be done without executing
    -n, --vm-name NAME      Override VM name (default: orchard)
    -i, --install-nixos     Install NixOS after VM creation
    -D, --destroy-existing  Destroy existing VM before creating new one
    -v, --verbose           Enable verbose output
    --nixos-version VER     NixOS version to install (default: $DEFAULT_NIXOS_VERSION)

EXAMPLES:
    # Create VM (dry run)
    $0 --dry-run

    # Create VM and install NixOS
    $0 --install-nixos

    # Recreate VM from scratch
    $0 --destroy-existing --install-nixos

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -n|--vm-name)
                VM_NAME="$2"
                shift 2
                ;;
            -i|--install-nixos)
                INSTALL_NIXOS=true
                shift
                ;;
            -D|--destroy-existing)
                DESTROY_EXISTING=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --nixos-version)
                DEFAULT_NIXOS_VERSION="$2"
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for Lima
    if ! command -v limactl &> /dev/null; then
        log_error "Lima (limactl) is not installed. Please install Lima first."
        log_info "Install with: brew install lima"
        return 1
    fi
    
    # Check Lima configuration exists
    if [[ ! -f "$LIMA_CONFIG" ]]; then
        log_error "Lima configuration not found: $LIMA_CONFIG"
        return 1
    fi
    
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is intended to run on macOS"
        return 1
    fi
    
    log_info "Prerequisites check passed"
    return 0
}

# Check if VM exists
vm_exists() {
    limactl list | grep -q "^${VM_NAME}\s"
}

# Get VM status
vm_status() {
    if vm_exists; then
        limactl list | grep "^${VM_NAME}\s" | awk '{print $2}'
    else
        echo "NotFound"
    fi
}

# Destroy existing VM
destroy_vm() {
    if vm_exists; then
        log_info "Destroying existing VM: $VM_NAME"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            dry_run_msg "limactl stop $VM_NAME"
            dry_run_msg "limactl delete $VM_NAME"
        else
            limactl stop "$VM_NAME" 2>/dev/null || true
            sleep 2
            limactl delete "$VM_NAME"
            log_info "VM destroyed successfully"
        fi
    else
        log_debug "VM does not exist, nothing to destroy"
    fi
}

# Create VM
create_vm() {
    log_info "Creating VM: $VM_NAME"
    
    if vm_exists && [[ "$DESTROY_EXISTING" != "true" ]]; then
        log_warning "VM already exists. Use --destroy-existing to recreate."
        return 1
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_msg "limactl start --name=$VM_NAME $LIMA_CONFIG"
        return 0
    fi
    
    # Create the VM
    log_info "Starting Lima VM..."
    if ! limactl start --name="$VM_NAME" "$LIMA_CONFIG" --tty=false; then
        log_error "Failed to create VM"
        return 1
    fi
    
    # Wait for VM to be ready
    log_info "Waiting for VM to be ready..."
    local max_attempts=60
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if [[ "$(vm_status)" == "Running" ]]; then
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
    
    # Verify SSH connectivity
    log_info "Verifying SSH connectivity..."
    if ! limactl shell "$VM_NAME" true; then
        log_error "Cannot connect to VM via SSH"
        return 1
    fi
    
    log_info "VM created successfully"
    return 0
}

# Install NixOS on the VM
install_nixos() {
    log_info "Installing NixOS on VM..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_msg "Install NixOS version $DEFAULT_NIXOS_VERSION on $VM_NAME"
        dry_run_msg "Configure VM with $ROOT_DIR/hosts/orchard/configuration.nix"
        return 0
    fi
    
    # Check VM is running
    if [[ "$(vm_status)" != "Running" ]]; then
        log_error "VM is not running"
        return 1
    fi
    
    # Install Nix first (single-user mode for simplicity in VM)
    log_info "Installing Nix package manager..."
    if ! limactl shell "$VM_NAME" sh -c "curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes"; then
        log_error "Failed to install Nix"
        return 1
    fi
    
    # Source Nix environment
    limactl shell "$VM_NAME" sh -c "echo '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' >> ~/.bashrc"
    
    # Prepare for NixOS installation
    log_info "Preparing NixOS installation..."
    
    # Create a script to run inside the VM
    local install_script=$(cat << 'EOSCRIPT'
#!/bin/bash
set -euo pipefail

# Source Nix
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Install nixos-install tools
nix-channel --add https://nixos.org/channels/nixos-${NIXOS_VERSION} nixos
nix-channel --update

# Generate hardware configuration
nixos-generate-config --root /mnt

# Copy our configuration
# Note: This would need to be copied from host to VM
echo "NixOS installation prepared"
echo "Next steps:"
echo "1. Copy configuration.nix to VM"
echo "2. Run nixos-install"
echo "3. Reboot into NixOS"
EOSCRIPT
    )
    
    # Note: Full NixOS installation would require:
    # 1. Partitioning the disk
    # 2. Mounting filesystems
    # 3. Copying configuration
    # 4. Running nixos-install
    # This is a complex process that would need more implementation
    
    log_warning "NixOS installation is partially implemented"
    log_info "Manual steps required to complete NixOS installation"
    
    return 0
}

# Get VM information
show_vm_info() {
    if ! vm_exists; then
        log_info "VM does not exist"
        return
    fi
    
    log_info "VM Information:"
    echo "  Name: $VM_NAME"
    echo "  Status: $(vm_status)"
    
    if [[ "$(vm_status)" == "Running" ]]; then
        local ssh_info=$(limactl list "$VM_NAME" -f '{{.SSHLocalPort}}' 2>/dev/null || echo "unknown")
        echo "  SSH Port: $ssh_info"
        echo "  SSH Command: limactl shell $VM_NAME"
        
        # Get IP address if available
        local ip=$(limactl shell "$VM_NAME" ip -4 -o addr show lima0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 || echo "unknown")
        echo "  IP Address: $ip"
    fi
}

# Main execution
main() {
    parse_args "$@"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Running in DRY RUN mode - no changes will be made"
    fi
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Handle VM destruction if requested
    if [[ "$DESTROY_EXISTING" == "true" ]]; then
        destroy_vm
    fi
    
    # Create VM if it doesn't exist
    if ! vm_exists; then
        if ! create_vm; then
            log_error "Failed to create VM"
            exit 1
        fi
    else
        log_info "VM already exists"
        show_vm_info
    fi
    
    # Install NixOS if requested
    if [[ "$INSTALL_NIXOS" == "true" ]]; then
        if ! install_nixos; then
            log_error "Failed to install NixOS"
            exit 1
        fi
    fi
    
    # Show final VM info
    if [[ "$DRY_RUN" != "true" ]]; then
        echo
        show_vm_info
    fi
    
    log_info "Provisioning complete!"
}

# Run main function
main "$@"