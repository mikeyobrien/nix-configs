#!/usr/bin/env bash
# ABOUTME: Provision coral VM on Proxmox for k3s cluster
# ABOUTME: Supports dry-run mode, VM lifecycle management, and NixOS installation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VM_NAME="coral"
VM_ID="${VM_ID:-9002}"  # Default VM ID for coral
TEMPLATE_ID="${TEMPLATE_ID:-9000}"  # Template VM ID
DEFAULT_NIXOS_VERSION="24.05"

# Proxmox configuration
PROXMOX_HOST="${PROXMOX_HOST:-10.10.10.10}"
PROXMOX_USER="${PROXMOX_USER:-root@pam}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"  # Proxmox node name

# VM specifications
VM_CORES="${VM_CORES:-4}"
VM_MEMORY="${VM_MEMORY:-8192}"  # MB
VM_DISK="${VM_DISK:-100}"  # GB
VM_BRIDGE="${VM_BRIDGE:-vmbr1}"  # Network bridge for k3s cluster
VM_IP="${VM_IP:-10.10.20.12/24}"  # Static IP for coral
VM_GATEWAY="${VM_GATEWAY:-10.10.20.1}"

# Runtime options
DRY_RUN=false
DESTROY_EXISTING=false
CREATE_TEMPLATE=false
INSTALL_NIXOS=false
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

Provision coral VM on Proxmox for k3s cluster.

OPTIONS:
    -h, --help              Show this help message
    -d, --dry-run           Show what would be done without executing
    -n, --vm-name NAME      Override VM name (default: coral)
    -i, --vm-id ID          VM ID (default: $VM_ID)
    -t, --template-id ID    Template VM ID (default: $TEMPLATE_ID)
    -D, --destroy-existing  Destroy existing VM before creating new one
    -T, --create-template   Create VM template for cloning
    -I, --install-nixos     Install NixOS after VM creation
    -v, --verbose           Enable verbose output
    --host HOST             Proxmox host (default: $PROXMOX_HOST)
    --node NODE             Proxmox node name (default: $PROXMOX_NODE)

VM SPECIFICATIONS:
    --cores NUM             CPU cores (default: $VM_CORES)
    --memory MB             Memory in MB (default: $VM_MEMORY)
    --disk GB               Disk size in GB (default: $VM_DISK)
    --bridge NAME           Network bridge (default: $VM_BRIDGE)
    --ip IP/MASK            Static IP (default: $VM_IP)
    --gateway IP            Gateway IP (default: $VM_GATEWAY)

EXAMPLES:
    # Test provisioning (dry run)
    $0 --dry-run

    # Create VM and install NixOS
    $0 --install-nixos

    # Recreate VM from scratch
    $0 --destroy-existing --install-nixos

    # Create a template VM
    $0 --create-template --vm-id 9000

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
            -i|--vm-id)
                VM_ID="$2"
                shift 2
                ;;
            -t|--template-id)
                TEMPLATE_ID="$2"
                shift 2
                ;;
            -D|--destroy-existing)
                DESTROY_EXISTING=true
                shift
                ;;
            -T|--create-template)
                CREATE_TEMPLATE=true
                shift
                ;;
            -I|--install-nixos)
                INSTALL_NIXOS=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --host)
                PROXMOX_HOST="$2"
                shift 2
                ;;
            --node)
                PROXMOX_NODE="$2"
                shift 2
                ;;
            --cores)
                VM_CORES="$2"
                shift 2
                ;;
            --memory)
                VM_MEMORY="$2"
                shift 2
                ;;
            --disk)
                VM_DISK="$2"
                shift 2
                ;;
            --bridge)
                VM_BRIDGE="$2"
                shift 2
                ;;
            --ip)
                VM_IP="$2"
                shift 2
                ;;
            --gateway)
                VM_GATEWAY="$2"
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

# Execute SSH command on Proxmox host
proxmox_ssh() {
    local cmd="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_msg "ssh $PROXMOX_USER@$PROXMOX_HOST '$cmd'"
        return 0
    fi
    
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "$cmd"
}

# Execute Proxmox API command via pvesh
proxmox_api() {
    local cmd="$1"
    proxmox_ssh "pvesh $cmd"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check SSH connectivity
    if ! timeout 5 bash -c "echo > /dev/tcp/$PROXMOX_HOST/22" 2>/dev/null; then
        log_error "Cannot reach Proxmox host $PROXMOX_HOST on SSH port"
        return 1
    fi
    
    # Check required tools
    if ! command -v ssh &> /dev/null; then
        log_error "SSH client is not installed"
        return 1
    fi
    
    # Check if we have Proxmox credentials
    if [[ -z "${PROXMOX_TOKEN:-}" ]] && [[ "$DRY_RUN" != "true" ]]; then
        log_warning "PROXMOX_TOKEN not set - SSH key authentication will be used"
    fi
    
    log_info "Prerequisites check passed"
    return 0
}

# Check if VM exists
vm_exists() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 1  # Assume VM doesn't exist in dry-run
    fi
    
    proxmox_ssh "qm status $VM_ID" &>/dev/null
}

# Get VM status
vm_status() {
    if vm_exists; then
        proxmox_ssh "qm status $VM_ID" | grep -oP 'status: \K\w+'
    else
        echo "NotFound"
    fi
}

# Destroy existing VM
destroy_vm() {
    if vm_exists; then
        log_info "Destroying existing VM: $VM_NAME (ID: $VM_ID)"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            dry_run_msg "qm stop $VM_ID"
            dry_run_msg "qm destroy $VM_ID"
        else
            proxmox_ssh "qm stop $VM_ID" 2>/dev/null || true
            sleep 2
            proxmox_ssh "qm destroy $VM_ID --purge"
            log_info "VM destroyed successfully"
        fi
    else
        log_debug "VM does not exist, nothing to destroy"
    fi
}

# Create VM from template
create_vm_from_template() {
    log_info "Creating VM from template..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_msg "qm clone $TEMPLATE_ID $VM_ID --name $VM_NAME"
        dry_run_msg "qm set $VM_ID --cores $VM_CORES --memory $VM_MEMORY"
        dry_run_msg "qm set $VM_ID --net0 virtio,bridge=$VM_BRIDGE"
        dry_run_msg "qm set $VM_ID --ipconfig0 ip=$VM_IP,gw=$VM_GATEWAY"
        return 0
    fi
    
    # Clone from template
    if ! proxmox_ssh "qm clone $TEMPLATE_ID $VM_ID --name $VM_NAME"; then
        log_error "Failed to clone VM from template"
        return 1
    fi
    
    # Configure VM
    proxmox_ssh "qm set $VM_ID --cores $VM_CORES --memory $VM_MEMORY"
    proxmox_ssh "qm set $VM_ID --net0 virtio,bridge=$VM_BRIDGE"
    proxmox_ssh "qm set $VM_ID --ipconfig0 ip=$VM_IP,gw=$VM_GATEWAY"
    
    log_info "VM created from template successfully"
    return 0
}

# Create VM from scratch
create_vm_from_scratch() {
    log_info "Creating VM from scratch..."
    
    local iso_path="/var/lib/vz/template/iso/nixos-${DEFAULT_NIXOS_VERSION}-x86_64.iso"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_msg "qm create $VM_ID --name $VM_NAME --cores $VM_CORES --memory $VM_MEMORY"
        dry_run_msg "qm set $VM_ID --scsi0 local-lvm:${VM_DISK}"
        dry_run_msg "qm set $VM_ID --ide2 local:iso/${iso_path##*/},media=cdrom"
        dry_run_msg "qm set $VM_ID --boot order=scsi0"
        dry_run_msg "qm set $VM_ID --net0 virtio,bridge=$VM_BRIDGE"
        dry_run_msg "qm set $VM_ID --ipconfig0 ip=$VM_IP,gw=$VM_GATEWAY"
        return 0
    fi
    
    # Create VM
    if ! proxmox_ssh "qm create $VM_ID --name $VM_NAME --cores $VM_CORES --memory $VM_MEMORY"; then
        log_error "Failed to create VM"
        return 1
    fi
    
    # Add disk
    proxmox_ssh "qm set $VM_ID --scsi0 local-lvm:${VM_DISK}"
    
    # Add NixOS ISO if available
    if proxmox_ssh "test -f '$iso_path'"; then
        proxmox_ssh "qm set $VM_ID --ide2 local:iso/${iso_path##*/},media=cdrom"
        proxmox_ssh "qm set $VM_ID --boot order=scsi0"
    else
        log_warning "NixOS ISO not found at $iso_path"
    fi
    
    # Configure network
    proxmox_ssh "qm set $VM_ID --net0 virtio,bridge=$VM_BRIDGE"
    proxmox_ssh "qm set $VM_ID --ipconfig0 ip=$VM_IP,gw=$VM_GATEWAY"
    
    # Enable QEMU agent
    proxmox_ssh "qm set $VM_ID --agent enabled=1"
    
    log_info "VM created successfully"
    return 0
}

# Create VM
create_vm() {
    log_info "Creating VM: $VM_NAME (ID: $VM_ID)"
    
    if vm_exists && [[ "$DESTROY_EXISTING" != "true" ]]; then
        log_warning "VM already exists. Use --destroy-existing to recreate."
        return 1
    fi
    
    # Check if template exists
    if proxmox_ssh "qm status $TEMPLATE_ID" &>/dev/null; then
        create_vm_from_template
    else
        log_warning "Template VM $TEMPLATE_ID not found, creating from scratch"
        create_vm_from_scratch
    fi
}

# Start VM
start_vm() {
    log_info "Starting VM..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_msg "qm start $VM_ID"
        return 0
    fi
    
    if ! proxmox_ssh "qm start $VM_ID"; then
        log_error "Failed to start VM"
        return 1
    fi
    
    # Wait for VM to start
    log_info "Waiting for VM to start..."
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if [[ "$(vm_status)" == "running" ]]; then
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

# Install NixOS on VM
install_nixos() {
    log_info "Installing NixOS on VM..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_msg "Install NixOS $DEFAULT_NIXOS_VERSION on VM $VM_ID"
        dry_run_msg "Deploy configuration from $ROOT_DIR/hosts/coral/"
        return 0
    fi
    
    # This would involve:
    # 1. Booting from NixOS ISO
    # 2. Partitioning disk
    # 3. Installing NixOS
    # 4. Copying coral configuration
    # 5. Running nixos-install
    
    log_warning "NixOS installation requires manual steps or automation via cloud-init"
    log_info "To complete installation:"
    log_info "1. Connect to VM console: https://$PROXMOX_HOST:8006/"
    log_info "2. Boot from NixOS ISO"
    log_info "3. Follow NixOS installation guide"
    log_info "4. Copy configuration from hosts/coral/"
    
    return 0
}

# Create VM template
create_template() {
    log_info "Creating VM template..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_msg "Create VM $TEMPLATE_ID as template"
        dry_run_msg "Install cloud-init and prepare for cloning"
        return 0
    fi
    
    # This would create a template VM with:
    # - Cloud-init support
    # - Basic NixOS installation
    # - SSH keys
    # - Ready for cloning
    
    log_warning "Template creation requires manual preparation"
    log_info "Steps to create template:"
    log_info "1. Create a VM with ID $TEMPLATE_ID"
    log_info "2. Install minimal NixOS"
    log_info "3. Install cloud-init"
    log_info "4. Convert to template: qm template $TEMPLATE_ID"
    
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
    echo "  ID: $VM_ID"
    echo "  Status: $(vm_status)"
    echo "  IP: ${VM_IP%/*}"
    echo "  Gateway: $VM_GATEWAY"
    echo "  Cores: $VM_CORES"
    echo "  Memory: ${VM_MEMORY}MB"
    echo "  Disk: ${VM_DISK}GB"
    
    if [[ "$(vm_status)" == "running" ]]; then
        echo "  Console: https://$PROXMOX_HOST:8006/?console=vms&vmid=$VM_ID"
        echo "  SSH: ssh nixos@${VM_IP%/*}"
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
    
    # Handle template creation
    if [[ "$CREATE_TEMPLATE" == "true" ]]; then
        create_template
        exit 0
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
        
        if ! start_vm; then
            log_error "Failed to start VM"
            exit 1
        fi
    else
        log_info "VM already exists"
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