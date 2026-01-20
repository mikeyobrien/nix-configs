#!/usr/bin/env bash
# ABOUTME: Check individual k3s node health and system resources
# ABOUTME: Monitors services, resources, containers, and k3s components

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Node connection details
NODE_HOST="${1:-localhost}"
NODE_USER="${NODE_USER:-nixos}"
NODE_PORT="${NODE_PORT:-22}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
IS_LOCAL="${IS_LOCAL:-false}"

# Thresholds
CPU_WARN="${CPU_WARN:-80}"
CPU_CRIT="${CPU_CRIT:-90}"
MEM_WARN="${MEM_WARN:-80}"
MEM_CRIT="${MEM_CRIT:-90}"
DISK_WARN="${DISK_WARN:-80}"
DISK_CRIT="${DISK_CRIT:-90}"

# Output format
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"  # text, json
VERBOSE="${VERBOSE:-false}"

# Health status
OVERALL_STATUS="healthy"
ISSUES=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        echo -e "${GREEN}[INFO]${NC} $1"
    fi
}

log_error() {
    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        echo -e "${RED}[ERROR]${NC} $1" >&2
    fi
}

log_warning() {
    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $1"
    fi
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]] && [[ "$OUTPUT_FORMAT" == "text" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

usage() {
    cat << EOF
Usage: $0 [node-host] [OPTIONS]

Check k3s node health and system resources.

ARGUMENTS:
    node-host           Node to check (default: localhost)

OPTIONS:
    -u, --user USER     SSH user (default: $NODE_USER)
    -p, --port PORT     SSH port (default: $NODE_PORT)
    -k, --key KEY       SSH key path (default: $SSH_KEY)
    -l, --local         Check local node (no SSH)
    -f, --format FORMAT Output format: text, json (default: $OUTPUT_FORMAT)
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

THRESHOLDS:
    --cpu-warn PCT      CPU warning threshold (default: $CPU_WARN%)
    --cpu-crit PCT      CPU critical threshold (default: $CPU_CRIT%)
    --mem-warn PCT      Memory warning threshold (default: $MEM_WARN%)
    --mem-crit PCT      Memory critical threshold (default: $MEM_CRIT%)
    --disk-warn PCT     Disk warning threshold (default: $DISK_WARN%)
    --disk-crit PCT     Disk critical threshold (default: $DISK_CRIT%)

ENVIRONMENT:
    NODE_USER           SSH user for node connection
    NODE_PORT           SSH port for node connection
    SSH_KEY             Path to SSH private key

EXAMPLES:
    # Check local node
    $0 --local

    # Check remote node
    $0 10.10.20.12

    # JSON output for monitoring
    $0 10.10.20.12 --format json

    # Verbose check with custom thresholds
    $0 --local --verbose --cpu-warn 70 --mem-warn 75

EOF
}

# Parse command line arguments
parse_args() {
    # Check for help flag first
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi
    
    # First argument might be node host
    if [[ -n "${1:-}" ]] && [[ ! "$1" =~ ^- ]]; then
        NODE_HOST="$1"
        shift
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--user)
                NODE_USER="$2"
                shift 2
                ;;
            -p|--port)
                NODE_PORT="$2"
                shift 2
                ;;
            -k|--key)
                SSH_KEY="$2"
                shift 2
                ;;
            -l|--local)
                IS_LOCAL=true
                NODE_HOST="localhost"
                shift
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --cpu-warn)
                CPU_WARN="$2"
                shift 2
                ;;
            --cpu-crit)
                CPU_CRIT="$2"
                shift 2
                ;;
            --mem-warn)
                MEM_WARN="$2"
                shift 2
                ;;
            --mem-crit)
                MEM_CRIT="$2"
                shift 2
                ;;
            --disk-warn)
                DISK_WARN="$2"
                shift 2
                ;;
            --disk-crit)
                DISK_CRIT="$2"
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

# Execute command on node
node_cmd() {
    if [[ "$IS_LOCAL" == "true" ]]; then
        bash -c "$1" 2>/dev/null
    else
        ssh -o ConnectTimeout=10 \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -p "$NODE_PORT" \
            -i "$SSH_KEY" \
            "$NODE_USER@$NODE_HOST" \
            "$1" 2>/dev/null
    fi
}

# Update health status
update_status() {
    local severity="$1"
    local message="$2"
    
    ISSUES+=("{\"severity\": \"$severity\", \"message\": \"$message\"}")
    
    case "$severity" in
        "critical")
            OVERALL_STATUS="critical"
            log_error "$message"
            ;;
        "warning")
            if [[ "$OVERALL_STATUS" != "critical" ]]; then
                OVERALL_STATUS="warning"
            fi
            log_warning "$message"
            ;;
        "info")
            log_info "$message"
            ;;
    esac
}

# Check system information
check_system_info() {
    log_debug "Checking system information..."
    
    local hostname=$(node_cmd "hostname" || echo "unknown")
    local kernel=$(node_cmd "uname -r" || echo "unknown")
    local uptime=$(node_cmd "uptime -p" || echo "unknown")
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "\"system\": {\"hostname\": \"$hostname\", \"kernel\": \"$kernel\", \"uptime\": \"$uptime\"}"
    else
        echo "=== System Information ==="
        echo "Hostname: $hostname"
        echo "Kernel: $kernel"
        echo "Uptime: $uptime"
        echo
    fi
}

# Check CPU usage
check_cpu() {
    log_debug "Checking CPU usage..."
    
    local cpu_usage=$(node_cmd "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - \$8}' | cut -d'.' -f1" || echo "0")
    local cpu_count=$(node_cmd "nproc" || echo "1")
    
    if [[ $cpu_usage -ge $CPU_CRIT ]]; then
        update_status "critical" "CPU usage critical: ${cpu_usage}% (threshold: ${CPU_CRIT}%)"
    elif [[ $cpu_usage -ge $CPU_WARN ]]; then
        update_status "warning" "CPU usage high: ${cpu_usage}% (threshold: ${CPU_WARN}%)"
    else
        log_debug "CPU usage normal: ${cpu_usage}%"
    fi
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "\"cpu\": {\"usage\": $cpu_usage, \"cores\": $cpu_count}"
    else
        echo "=== CPU Usage ==="
        echo "Usage: ${cpu_usage}%"
        echo "Cores: $cpu_count"
        echo
    fi
}

# Check memory usage
check_memory() {
    log_debug "Checking memory usage..."
    
    local mem_info=$(node_cmd "free -m | grep '^Mem:' | awk '{print \$2, \$3, \$4}'")
    local mem_total=$(echo "$mem_info" | awk '{print $1}')
    local mem_used=$(echo "$mem_info" | awk '{print $2}')
    local mem_free=$(echo "$mem_info" | awk '{print $3}')
    local mem_usage=$((mem_used * 100 / mem_total))
    
    if [[ $mem_usage -ge $MEM_CRIT ]]; then
        update_status "critical" "Memory usage critical: ${mem_usage}% (threshold: ${MEM_CRIT}%)"
    elif [[ $mem_usage -ge $MEM_WARN ]]; then
        update_status "warning" "Memory usage high: ${mem_usage}% (threshold: ${MEM_WARN}%)"
    else
        log_debug "Memory usage normal: ${mem_usage}%"
    fi
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "\"memory\": {\"total\": $mem_total, \"used\": $mem_used, \"free\": $mem_free, \"usage\": $mem_usage}"
    else
        echo "=== Memory Usage ==="
        echo "Total: ${mem_total}MB"
        echo "Used: ${mem_used}MB (${mem_usage}%)"
        echo "Free: ${mem_free}MB"
        echo
    fi
}

# Check disk usage
check_disk() {
    log_debug "Checking disk usage..."
    
    local disk_usage=$(node_cmd "df -h / | tail -1 | awk '{print \$5}' | tr -d '%'" || echo "0")
    local disk_info=$(node_cmd "df -h / | tail -1" || echo "unknown")
    
    if [[ $disk_usage -ge $DISK_CRIT ]]; then
        update_status "critical" "Disk usage critical: ${disk_usage}% (threshold: ${DISK_CRIT}%)"
    elif [[ $disk_usage -ge $DISK_WARN ]]; then
        update_status "warning" "Disk usage high: ${disk_usage}% (threshold: ${DISK_WARN}%)"
    else
        log_debug "Disk usage normal: ${disk_usage}%"
    fi
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "\"disk\": {\"usage\": $disk_usage, \"info\": \"$disk_info\"}"
    else
        echo "=== Disk Usage ==="
        echo "$disk_info"
        echo
    fi
}

# Check k3s service
check_k3s_service() {
    log_debug "Checking k3s service..."
    
    local service_name="k3s"
    if node_cmd "systemctl is-active k3s-server" >/dev/null 2>&1; then
        service_name="k3s-server"
    elif node_cmd "systemctl is-active k3s-agent" >/dev/null 2>&1; then
        service_name="k3s-agent"
    fi
    
    local service_status=$(node_cmd "systemctl is-active $service_name" || echo "inactive")
    local service_enabled=$(node_cmd "systemctl is-enabled $service_name" 2>/dev/null || echo "disabled")
    
    if [[ "$service_status" != "active" ]]; then
        update_status "critical" "K3s service not active: $service_name is $service_status"
    elif [[ "$service_enabled" != "enabled" ]]; then
        update_status "warning" "K3s service not enabled: $service_name"
    else
        log_debug "K3s service healthy: $service_name"
    fi
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "\"k3s_service\": {\"name\": \"$service_name\", \"status\": \"$service_status\", \"enabled\": \"$service_enabled\"}"
    else
        echo "=== K3s Service ==="
        echo "Service: $service_name"
        echo "Status: $service_status"
        echo "Enabled: $service_enabled"
        echo
    fi
}

# Check k3s node status
check_k3s_node() {
    log_debug "Checking k3s node status..."
    
    if ! node_cmd "command -v kubectl" >/dev/null; then
        update_status "warning" "kubectl not found, skipping k3s node check"
        return
    fi
    
    local node_info=$(node_cmd "kubectl get node \$(hostname) -o wide --no-headers" 2>/dev/null || echo "")
    
    if [[ -z "$node_info" ]]; then
        update_status "warning" "Cannot get k3s node status"
        return
    fi
    
    local node_status=$(echo "$node_info" | awk '{print $2}')
    local node_roles=$(echo "$node_info" | awk '{print $3}')
    local kubelet_version=$(echo "$node_info" | awk '{print $5}')
    
    if [[ "$node_status" != "Ready" ]]; then
        update_status "critical" "K3s node not ready: $node_status"
    else
        log_debug "K3s node ready"
    fi
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "\"k3s_node\": {\"status\": \"$node_status\", \"roles\": \"$node_roles\", \"version\": \"$kubelet_version\"}"
    else
        echo "=== K3s Node Status ==="
        echo "Status: $node_status"
        echo "Roles: $node_roles"
        echo "Version: $kubelet_version"
        echo
    fi
}

# Check container runtime
check_containers() {
    log_debug "Checking container runtime..."
    
    local runtime="unknown"
    local container_count=0
    
    if node_cmd "command -v crictl" >/dev/null; then
        runtime="containerd"
        container_count=$(node_cmd "crictl ps -q 2>/dev/null | wc -l" || echo "0")
    elif node_cmd "command -v docker" >/dev/null; then
        runtime="docker"
        container_count=$(node_cmd "docker ps -q 2>/dev/null | wc -l" || echo "0")
    fi
    
    if [[ "$runtime" == "unknown" ]]; then
        update_status "warning" "No container runtime detected"
    else
        log_debug "Container runtime: $runtime, running containers: $container_count"
    fi
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "\"containers\": {\"runtime\": \"$runtime\", \"count\": $container_count}"
    else
        echo "=== Container Runtime ==="
        echo "Runtime: $runtime"
        echo "Running containers: $container_count"
        echo
    fi
}

# Check network connectivity
check_network() {
    log_debug "Checking network connectivity..."
    
    local network_ok=true
    local issues=""
    
    # Check default gateway
    if ! node_cmd "ip route | grep -q '^default'"; then
        network_ok=false
        issues="No default gateway"
    fi
    
    # Check DNS resolution
    if ! node_cmd "nslookup kubernetes.default.svc.cluster.local" >/dev/null 2>&1; then
        if ! node_cmd "nslookup google.com" >/dev/null 2>&1; then
            network_ok=false
            issues="${issues:+$issues, }DNS resolution failed"
        fi
    fi
    
    # Check k3s API connectivity (if local)
    if node_cmd "test -f /etc/rancher/k3s/k3s.yaml" 2>/dev/null; then
        if ! node_cmd "curl -sk https://localhost:6443/healthz" >/dev/null 2>&1; then
            network_ok=false
            issues="${issues:+$issues, }K3s API unreachable"
        fi
    fi
    
    if [[ "$network_ok" == "false" ]]; then
        update_status "warning" "Network issues: $issues"
    else
        log_debug "Network connectivity healthy"
    fi
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "\"network\": {\"healthy\": $network_ok, \"issues\": \"$issues\"}"
    else
        echo "=== Network Status ==="
        echo "Healthy: $network_ok"
        if [[ -n "$issues" ]]; then
            echo "Issues: $issues"
        fi
        echo
    fi
}

# Generate JSON output
generate_json_output() {
    echo "{"
    check_system_info
    echo ","
    check_cpu
    echo ","
    check_memory
    echo ","
    check_disk
    echo ","
    check_k3s_service
    echo ","
    check_k3s_node
    echo ","
    check_containers
    echo ","
    check_network
    echo ","
    echo "\"overall_status\": \"$OVERALL_STATUS\","
    echo "\"issues\": ["
    local first=true
    for issue in "${ISSUES[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        echo -n "  $issue"
    done
    echo
    echo "]"
    echo "}"
}

# Main execution
main() {
    parse_args "$@"
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        generate_json_output
    else
        echo "====================================="
        echo "K3s Node Health Check: $NODE_HOST"
        echo "====================================="
        echo
        
        check_system_info
        check_cpu
        check_memory
        check_disk
        check_k3s_service
        check_k3s_node
        check_containers
        check_network
        
        echo "====================================="
        echo "Overall Status: $OVERALL_STATUS"
        if [[ ${#ISSUES[@]} -gt 0 ]]; then
            echo "Issues found: ${#ISSUES[@]}"
        fi
        echo "====================================="
    fi
    
    # Exit with appropriate code
    case "$OVERALL_STATUS" in
        "healthy")
            exit 0
            ;;
        "warning")
            exit 1
            ;;
        "critical")
            exit 2
            ;;
    esac
}

# Run main function
main "$@"