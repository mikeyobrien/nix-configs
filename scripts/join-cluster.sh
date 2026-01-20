#!/usr/bin/env bash
# ABOUTME: Join a node to existing k3s cluster as server or agent
# ABOUTME: Handles k3s installation, token auth, and service configuration

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cluster configuration
MASTER_NODE="${MASTER_NODE:-}"
JOIN_TOKEN="${JOIN_TOKEN:-}"
NODE_HOST="${NODE_HOST:-localhost}"
NODE_ROLE="${NODE_ROLE:-agent}"  # agent or server
NODE_NAME="${NODE_NAME:-}"  # Optional custom node name

# K3s configuration
K3S_VERSION="${K3S_VERSION:-stable}"
K3S_ARGS="${K3S_ARGS:-}"
CLUSTER_CIDR="${CLUSTER_CIDR:-10.42.0.0/16}"
SERVICE_CIDR="${SERVICE_CIDR:-10.43.0.0/16}"

# Runtime options
DRY_RUN="${DRY_RUN:-false}"
FORCE="${FORCE:-false}"
UNINSTALL_FIRST="${UNINSTALL_FIRST:-false}"

# SSH configuration for remote nodes
SSH_USER="${SSH_USER:-root}"
SSH_PORT="${SSH_PORT:-22}"
SSH_KEY="${SSH_KEY:-}"

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

dry_run_msg() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would execute: $1"
    fi
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Join a node to an existing k3s cluster.

OPTIONS:
    -m, --master HOST       Master node address (required)
    -t, --token TOKEN       Join token (required)
    -n, --node HOST         Node to join (default: localhost)
    -r, --role ROLE         Node role: agent, server (default: $NODE_ROLE)
    --name NAME             Custom node name (default: hostname)
    -d, --dry-run           Show what would be done without executing
    -f, --force             Force join even if already in cluster
    -u, --uninstall-first   Uninstall existing k3s before joining
    -h, --help              Show this help message

K3S OPTIONS:
    --k3s-version VERSION   K3s version to install (default: $K3S_VERSION)
    --k3s-args ARGS         Additional k3s arguments
    --cluster-cidr CIDR     Cluster pod CIDR (default: $CLUSTER_CIDR)
    --service-cidr CIDR     Service CIDR (default: $SERVICE_CIDR)

SSH OPTIONS (for remote nodes):
    --ssh-user USER         SSH user (default: $SSH_USER)
    --ssh-port PORT         SSH port (default: $SSH_PORT)
    --ssh-key KEY           SSH private key path

ENVIRONMENT:
    MASTER_NODE             Master node address
    JOIN_TOKEN              K3s join token
    NODE_HOST               Node to join
    NODE_ROLE               Node role (agent/server)

EXAMPLES:
    # Join local node as agent
    $0 --master 10.10.20.11 --token K10xxx...

    # Join remote node as server (HA)
    $0 --master 10.10.20.11 --token K10xxx... --node 10.10.20.13 --role server

    # Dry run to see what would happen
    $0 --master 10.10.20.11 --token K10xxx... --dry-run

    # Force rejoin with cleanup
    $0 --master 10.10.20.11 --token K10xxx... --uninstall-first --force

EOF
}

# Parse command line arguments
parse_args() {
    # Check for help flag first
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--master)
                MASTER_NODE="$2"
                shift 2
                ;;
            -t|--token)
                JOIN_TOKEN="$2"
                shift 2
                ;;
            -n|--node)
                NODE_HOST="$2"
                shift 2
                ;;
            -r|--role)
                NODE_ROLE="$2"
                shift 2
                ;;
            --name)
                NODE_NAME="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -u|--uninstall-first)
                UNINSTALL_FIRST=true
                shift
                ;;
            --k3s-version)
                K3S_VERSION="$2"
                shift 2
                ;;
            --k3s-args)
                K3S_ARGS="$2"
                shift 2
                ;;
            --cluster-cidr)
                CLUSTER_CIDR="$2"
                shift 2
                ;;
            --service-cidr)
                SERVICE_CIDR="$2"
                shift 2
                ;;
            --ssh-user)
                SSH_USER="$2"
                shift 2
                ;;
            --ssh-port)
                SSH_PORT="$2"
                shift 2
                ;;
            --ssh-key)
                SSH_KEY="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate required options
    if [[ -z "$MASTER_NODE" ]] || [[ -z "$JOIN_TOKEN" ]]; then
        log_error "Master node and join token are required"
        usage
        exit 1
    fi
    
    # Validate node role
    if [[ "$NODE_ROLE" != "agent" ]] && [[ "$NODE_ROLE" != "server" ]]; then
        log_error "Invalid node role: $NODE_ROLE (must be 'agent' or 'server')"
        exit 1
    fi
}

# Execute command on node
node_cmd() {
    local cmd="$1"
    
    if [[ "$NODE_HOST" == "localhost" ]] || [[ "$NODE_HOST" == "127.0.0.1" ]]; then
        # Local execution
        if [[ "$DRY_RUN" == "true" ]]; then
            dry_run_msg "$cmd"
            return 0
        else
            bash -c "$cmd"
        fi
    else
        # Remote execution
        local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        ssh_opts="$ssh_opts -p $SSH_PORT"
        
        if [[ -n "$SSH_KEY" ]]; then
            ssh_opts="$ssh_opts -i $SSH_KEY"
        fi
        
        if [[ "$DRY_RUN" == "true" ]]; then
            dry_run_msg "ssh $ssh_opts $SSH_USER@$NODE_HOST '$cmd'"
            return 0
        else
            ssh $ssh_opts "$SSH_USER@$NODE_HOST" "$cmd"
        fi
    fi
}

# Check if node already has k3s
check_existing_k3s() {
    log_info "Checking for existing k3s installation..."
    
    if node_cmd "command -v k3s" >/dev/null 2>&1; then
        log_warning "K3s is already installed on node"
        
        if [[ "$UNINSTALL_FIRST" == "true" ]]; then
            log_info "Uninstalling existing k3s..."
            uninstall_k3s
        elif [[ "$FORCE" != "true" ]]; then
            log_error "Node already has k3s installed. Use --force to override or --uninstall-first to remove"
            exit 1
        fi
    else
        log_info "No existing k3s installation found"
    fi
}

# Uninstall k3s
uninstall_k3s() {
    log_info "Uninstalling k3s from node..."
    
    # Try k3s uninstall scripts
    if node_cmd "test -f /usr/local/bin/k3s-uninstall.sh" 2>/dev/null; then
        node_cmd "/usr/local/bin/k3s-uninstall.sh"
    elif node_cmd "test -f /usr/local/bin/k3s-agent-uninstall.sh" 2>/dev/null; then
        node_cmd "/usr/local/bin/k3s-agent-uninstall.sh"
    else
        log_warning "No k3s uninstall script found, attempting manual cleanup"
        node_cmd "systemctl stop k3s k3s-agent" 2>/dev/null || true
        node_cmd "systemctl disable k3s k3s-agent" 2>/dev/null || true
        node_cmd "rm -rf /etc/rancher/k3s /var/lib/rancher/k3s /usr/local/bin/k3s*"
    fi
    
    log_info "K3s uninstalled"
}

# Install k3s
install_k3s() {
    log_info "Installing k3s version: $K3S_VERSION"
    
    # Build k3s install command
    local install_cmd="curl -sfL https://get.k3s.io | "
    
    # Environment variables for installation
    install_cmd+="INSTALL_K3S_VERSION='$K3S_VERSION' "
    install_cmd+="K3S_URL='https://$MASTER_NODE:6443' "
    install_cmd+="K3S_TOKEN='$JOIN_TOKEN' "
    
    if [[ -n "$NODE_NAME" ]]; then
        install_cmd+="K3S_NODE_NAME='$NODE_NAME' "
    fi
    
    # Role-specific configuration
    if [[ "$NODE_ROLE" == "server" ]]; then
        install_cmd+="INSTALL_K3S_EXEC='server "
        install_cmd+="--server https://$MASTER_NODE:6443 "
        install_cmd+="--cluster-cidr $CLUSTER_CIDR "
        install_cmd+="--service-cidr $SERVICE_CIDR "
        # For HA, disable local storage and traefik on additional servers
        install_cmd+="--disable traefik "
        install_cmd+="--disable servicelb "
    else
        install_cmd+="INSTALL_K3S_EXEC='agent "
    fi
    
    # Add any custom k3s arguments
    if [[ -n "$K3S_ARGS" ]]; then
        install_cmd+="$K3S_ARGS "
    fi
    
    install_cmd+="' sh -"
    
    # Execute installation
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_msg "$install_cmd"
    else
        log_info "Running k3s installation..."
        if ! node_cmd "$install_cmd"; then
            log_error "K3s installation failed"
            exit 1
        fi
        log_info "K3s installed successfully"
    fi
}

# Configure firewall rules
configure_firewall() {
    log_info "Configuring firewall rules..."
    
    # Required ports for k3s
    local tcp_ports=(
        "6443"   # Kubernetes API
        "10250"  # Kubelet metrics
        "2379"   # etcd client (HA servers)
        "2380"   # etcd peer (HA servers)
    )
    
    local udp_ports=(
        "8472"   # VXLAN
        "51820"  # Wireguard (if using)
        "51821"  # Wireguard (if using)
    )
    
    # Check if firewall is active
    if node_cmd "command -v ufw" >/dev/null 2>&1; then
        log_info "Configuring UFW firewall..."
        
        for port in "${tcp_ports[@]}"; do
            dry_run_msg "ufw allow $port/tcp"
            if [[ "$DRY_RUN" != "true" ]]; then
                node_cmd "ufw allow $port/tcp" || true
            fi
        done
        
        for port in "${udp_ports[@]}"; do
            dry_run_msg "ufw allow $port/udp"
            if [[ "$DRY_RUN" != "true" ]]; then
                node_cmd "ufw allow $port/udp" || true
            fi
        done
    elif node_cmd "command -v firewall-cmd" >/dev/null 2>&1; then
        log_info "Configuring firewalld..."
        
        for port in "${tcp_ports[@]}"; do
            dry_run_msg "firewall-cmd --permanent --add-port=$port/tcp"
            if [[ "$DRY_RUN" != "true" ]]; then
                node_cmd "firewall-cmd --permanent --add-port=$port/tcp" || true
            fi
        done
        
        for port in "${udp_ports[@]}"; do
            dry_run_msg "firewall-cmd --permanent --add-port=$port/udp"
            if [[ "$DRY_RUN" != "true" ]]; then
                node_cmd "firewall-cmd --permanent --add-port=$port/udp" || true
            fi
        done
        
        if [[ "$DRY_RUN" != "true" ]]; then
            node_cmd "firewall-cmd --reload" || true
        fi
    else
        log_info "No recognized firewall found, skipping firewall configuration"
    fi
}

# Wait for node to be ready
wait_for_node() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Would wait for node to join cluster and become ready"
        return 0
    fi
    
    log_info "Waiting for k3s service to start..."
    
    local service_name="k3s"
    if [[ "$NODE_ROLE" == "server" ]]; then
        service_name="k3s"
    else
        service_name="k3s-agent"
    fi
    
    # Wait for service to be active
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if node_cmd "systemctl is-active $service_name" >/dev/null 2>&1; then
            log_info "K3s service is active"
            break
        fi
        sleep 2
        ((attempt++))
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        log_error "K3s service did not start within timeout"
        exit 1
    fi
    
    # For local node, check if it appears in cluster
    if [[ "$NODE_HOST" == "localhost" ]] || [[ "$NODE_HOST" == "127.0.0.1" ]]; then
        log_info "Checking if node joined cluster..."
        
        attempt=0
        while [[ $attempt -lt $max_attempts ]]; do
            if kubectl get nodes | grep -q "$(hostname)"; then
                log_info "Node successfully joined cluster"
                break
            fi
            sleep 2
            ((attempt++))
        done
    fi
}

# Display node information
show_node_info() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Join process completed (dry-run)"
        return
    fi
    
    log_info "Node join completed!"
    echo
    echo "Node information:"
    echo "  Host: $NODE_HOST"
    echo "  Role: $NODE_ROLE"
    echo "  Master: $MASTER_NODE"
    
    if [[ "$NODE_HOST" == "localhost" ]] || [[ "$NODE_HOST" == "127.0.0.1" ]]; then
        echo
        echo "To verify node status:"
        echo "  kubectl get nodes"
        echo "  sudo systemctl status k3s${NODE_ROLE:+-}${NODE_ROLE}"
    else
        echo
        echo "To verify node status:"
        echo "  kubectl get nodes"
        echo "  ssh $SSH_USER@$NODE_HOST 'systemctl status k3s${NODE_ROLE:+-}${NODE_ROLE}'"
    fi
}

# Main execution
main() {
    parse_args "$@"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Running in DRY RUN mode - no changes will be made"
    fi
    
    log_info "Joining node to k3s cluster..."
    log_info "Node: $NODE_HOST"
    log_info "Role: $NODE_ROLE"
    log_info "Master: $MASTER_NODE"
    
    # Check for existing k3s installation
    check_existing_k3s
    
    # Install k3s
    install_k3s
    
    # Configure firewall
    configure_firewall
    
    # Wait for node to be ready
    wait_for_node
    
    # Show final information
    show_node_info
    
    log_info "Cluster join process completed successfully!"
}

# Run main function
main "$@"