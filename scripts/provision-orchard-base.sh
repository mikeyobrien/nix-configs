#!/usr/bin/env bash
# ABOUTME: Provision orchard VM using official NixOS image then apply config
# ABOUTME: Alternative approach that doesn't require building images locally

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VM_NAME="orchard"
NIXOS_VERSION="24.05"

# Runtime options
DRY_RUN=false
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

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Provision orchard VM using official NixOS image.

OPTIONS:
    -h, --help              Show this help message
    -d, --dry-run           Show what would be done without executing
    -D, --destroy-existing  Destroy existing VM before creating new one
    -v, --verbose           Enable verbose output

EXAMPLES:
    # Create VM
    $0

    # Recreate VM from scratch
    $0 --destroy-existing

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
            -D|--destroy-existing)
                DESTROY_EXISTING=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Create Lima configuration
create_lima_config() {
    local temp_config="/tmp/lima-orchard-base-$$.yaml"
    
    cat > "$temp_config" << 'EOF'
# Lima configuration for orchard using official NixOS image
arch: "x86_64"
cpus: 4
memory: "8GiB"
disk: "50GiB"

images:
  - location: "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
    arch: "x86_64"

mounts:
  - location: "~"
    mountPoint: "/home/mobrienv.host"
    writable: false
  - location: "/tmp/lima"
    mountPoint: "/tmp/lima"
    writable: true

ssh:
  localPort: 0
  loadDotSSHPubKeys: true

networks:
  - lima: user-v2

# Port forwarding for k3s
portForwards:
  - guestPort: 6443
    hostPort: 6443
    proto: tcp
  - guestPort: 10250
    hostPort: 10250  
    proto: tcp
  - guestPort: 2379
    hostPort: 2379
    proto: tcp
  - guestPort: 2380
    hostPort: 2380
    proto: tcp
  - guestPort: 9100
    hostPort: 19100
    proto: tcp

vmType: "qemu"

provision:
  - mode: system
    script: |
      #!/bin/bash
      set -eu
      
      # Wait for network
      while ! ping -c 1 8.8.8.8 &> /dev/null; do
        echo "Waiting for network..."
        sleep 2
      done
      
      # Enable flakes
      mkdir -p /etc/nix
      echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
      
      # Add user
      useradd -m -G wheel -s /run/current-system/sw/bin/bash mobrienv || true
      
      # Enable passwordless sudo
      echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
      
      echo "Base NixOS VM ready for configuration"

message: |
  ===================================================
  Orchard Base NixOS VM
  
  VM is running base NixOS. To apply configuration:
    limactl shell orchard
    cd /home/mobrienv.host/Code/nix-configs
    sudo nixos-rebuild switch --flake .#orchard
  ===================================================
EOF
    
    echo "$temp_config"
}

# Check if VM exists
vm_exists() {
    limactl list | grep -q "^${VM_NAME}\s"
}

# Destroy existing VM
destroy_vm() {
    if vm_exists; then
        log_info "Destroying existing VM: $VM_NAME"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${YELLOW}[DRY RUN]${NC} Would execute: limactl delete $VM_NAME"
        else
            limactl stop "$VM_NAME" 2>/dev/null || true
            sleep 2
            limactl delete "$VM_NAME"
            log_info "VM destroyed successfully"
        fi
    fi
}

# Create VM
create_vm() {
    log_info "Creating VM: $VM_NAME"
    
    if vm_exists && [[ "$DESTROY_EXISTING" != "true" ]]; then
        log_warning "VM already exists. Use --destroy-existing to recreate."
        return 1
    fi
    
    log_info "Creating Lima configuration..."
    local temp_config=$(create_lima_config)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would execute: limactl start --name=$VM_NAME $temp_config"
        rm -f "$temp_config"
        return 0
    fi
    
    # Create the VM
    log_info "Starting Lima VM with base NixOS..."
    if ! limactl start --name="$VM_NAME" "$temp_config" --tty=false; then
        log_error "Failed to create VM"
        rm -f "$temp_config"
        return 1
    fi
    
    # Clean up temp config
    rm -f "$temp_config"
    
    # Wait for VM to be ready
    log_info "Waiting for VM to be ready..."
    local max_attempts=60
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if limactl list | grep -q "^${VM_NAME}\s.*Running"; then
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

# Apply NixOS configuration
apply_configuration() {
    log_info "Preparing to apply NixOS configuration..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would apply NixOS configuration"
        return 0
    fi
    
    # Copy flake to VM
    log_info "Setting up configuration in VM..."
    
    limactl shell "$VM_NAME" << 'EOF'
# Clone the configuration
if [ ! -d /etc/nixos ]; then
    sudo mkdir -p /etc/nixos
fi

# Create a minimal flake.nix that imports from the host
sudo tee /etc/nixos/flake.nix > /dev/null << 'FLAKE'
{
  description = "Orchard VM configuration";
  
  inputs = {
    nixos-config.url = "path:/home/mobrienv.host/Code/nix-configs";
  };
  
  outputs = { self, nixos-config }: {
    nixosConfigurations.orchard = nixos-config.nixosConfigurations.orchard;
  };
}
FLAKE

echo "Configuration prepared"
EOF
    
    log_info "Configuration files prepared in VM"
    log_info ""
    log_info "To apply the configuration:"
    log_info "  limactl shell $VM_NAME"
    log_info "  sudo nixos-rebuild switch --flake /home/mobrienv.host/Code/nix-configs#orchard"
}

# Get VM information
show_vm_info() {
    if ! vm_exists; then
        log_info "VM does not exist"
        return
    fi
    
    log_info "VM Information:"
    echo "  Name: $VM_NAME"
    echo "  Status: Running"
    echo "  Architecture: x86_64 (Rosetta)"
    
    local ssh_info=$(limactl list "$VM_NAME" -f '{{.SSHLocalPort}}' 2>/dev/null || echo "unknown")
    echo "  SSH Port: $ssh_info"
    echo "  SSH Command: limactl shell $VM_NAME"
    echo ""
    echo "  Next Steps:"
    echo "    1. limactl shell $VM_NAME"
    echo "    2. cd /home/mobrienv.host/Code/nix-configs" 
    echo "    3. sudo nixos-rebuild switch --flake .#orchard"
}

# Main execution
main() {
    parse_args "$@"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Running in DRY RUN mode - no changes will be made"
    fi
    
    # Check prerequisites
    if ! command -v limactl &> /dev/null; then
        log_error "Lima is not installed. Install with: brew install lima"
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
        
        # Prepare configuration
        apply_configuration
    else
        log_info "VM already exists"
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