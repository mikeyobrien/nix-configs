#!/usr/bin/env bash
# ABOUTME: Test metric collection from k3s cluster nodes
# ABOUTME: Validates key metrics format, values, and aggregation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test configuration
NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"
TARGET_NODES=()  # Will be populated from args or auto-detected
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"  # text, json, prometheus

# Metric thresholds for validation
CPU_IDLE_MIN="${CPU_IDLE_MIN:-10}"  # Minimum idle CPU %
MEM_AVAILABLE_MIN="${MEM_AVAILABLE_MIN:-10}"  # Minimum available memory %
DISK_FREE_MIN="${DISK_FREE_MIN:-10}"  # Minimum free disk %

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

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Test metric collection from k3s cluster nodes.

OPTIONS:
    -n, --nodes LIST        Comma-separated list of nodes to test
    -p, --port PORT         Node exporter port (default: $NODE_EXPORTER_PORT)
    -f, --format FORMAT     Output format: text, json, prometheus (default: $OUTPUT_FORMAT)
    --cpu-idle-min PCT      Minimum idle CPU % threshold (default: $CPU_IDLE_MIN)
    --mem-min PCT           Minimum available memory % (default: $MEM_AVAILABLE_MIN)
    --disk-min PCT          Minimum free disk % (default: $DISK_FREE_MIN)
    -h, --help              Show this help message

ENVIRONMENT:
    NODE_EXPORTER_PORT      Port for node exporter metrics
    KUBECONFIG              Path to kubeconfig file

EXAMPLES:
    # Test metrics on all nodes
    $0

    # Test specific nodes with JSON output
    $0 --nodes "10.10.20.11,10.10.20.12" --format json

    # Test with custom thresholds
    $0 --cpu-idle-min 5 --mem-min 20 --disk-min 15

    # Get Prometheus-format output
    $0 --format prometheus

METRICS TESTED:
    - CPU usage and idle time
    - Memory usage and availability
    - Disk usage and free space
    - Network traffic and errors
    - System load averages
    - Container metrics (if available)

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
            -n|--nodes)
                IFS=',' read -ra TARGET_NODES <<< "$2"
                shift 2
                ;;
            -p|--port)
                NODE_EXPORTER_PORT="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --cpu-idle-min)
                CPU_IDLE_MIN="$2"
                shift 2
                ;;
            --mem-min)
                MEM_AVAILABLE_MIN="$2"
                shift 2
                ;;
            --disk-min)
                DISK_FREE_MIN="$2"
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

# Auto-detect cluster nodes
detect_nodes() {
    if [[ ${#TARGET_NODES[@]} -eq 0 ]]; then
        log_info "Auto-detecting cluster nodes..."
        
        # Get all nodes
        local nodes=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
        
        if [[ -n "$nodes" ]]; then
            IFS=' ' read -ra TARGET_NODES <<< "$nodes"
            log_info "Detected nodes: ${TARGET_NODES[*]}"
        else
            log_error "Could not detect cluster nodes"
            return 1
        fi
    fi
    
    return 0
}

# Get metric value from node
get_metric() {
    local node="$1"
    local metric_name="$2"
    local label_filter="${3:-}"
    
    local url="http://$node:$NODE_EXPORTER_PORT/metrics"
    local metrics=$(curl -sf "$url" 2>/dev/null || echo "")
    
    if [[ -z "$metrics" ]]; then
        echo "error"
        return 1
    fi
    
    if [[ -n "$label_filter" ]]; then
        echo "$metrics" | grep "^$metric_name{.*$label_filter" | tail -1 | awk '{print $2}'
    else
        echo "$metrics" | grep "^$metric_name " | tail -1 | awk '{print $2}'
    fi
}

# Calculate CPU usage
calculate_cpu_usage() {
    local node="$1"
    
    # Get CPU seconds for all modes
    local idle=$(get_metric "$node" "node_cpu_seconds_total" 'mode="idle"' | awk '{s+=$1} END {print s}')
    local total=0
    
    for mode in idle user system iowait irq softirq steal; do
        local val=$(get_metric "$node" "node_cpu_seconds_total" "mode=\"$mode\"" | awk '{s+=$1} END {print s}')
        if [[ "$val" != "error" ]] && [[ -n "$val" ]]; then
            total=$(echo "$total + $val" | bc)
        fi
    done
    
    if [[ "$total" == "0" ]] || [[ -z "$idle" ]]; then
        echo "error"
        return 1
    fi
    
    # Calculate idle percentage
    local idle_pct=$(echo "scale=2; ($idle / $total) * 100" | bc)
    echo "$idle_pct"
}

# Calculate memory usage
calculate_memory_usage() {
    local node="$1"
    
    local total=$(get_metric "$node" "node_memory_MemTotal_bytes")
    local available=$(get_metric "$node" "node_memory_MemAvailable_bytes")
    
    if [[ "$total" == "error" ]] || [[ "$available" == "error" ]] || [[ -z "$total" ]] || [[ -z "$available" ]]; then
        echo "error"
        return 1
    fi
    
    local available_pct=$(echo "scale=2; ($available / $total) * 100" | bc)
    echo "$available_pct"
}

# Calculate disk usage
calculate_disk_usage() {
    local node="$1"
    
    # Get root filesystem metrics
    local size=$(get_metric "$node" "node_filesystem_size_bytes" 'mountpoint="/"')
    local avail=$(get_metric "$node" "node_filesystem_avail_bytes" 'mountpoint="/"')
    
    if [[ "$size" == "error" ]] || [[ "$avail" == "error" ]] || [[ -z "$size" ]] || [[ -z "$avail" ]]; then
        echo "error"
        return 1
    fi
    
    local free_pct=$(echo "scale=2; ($avail / $size) * 100" | bc)
    echo "$free_pct"
}

# Get system load
get_system_load() {
    local node="$1"
    
    local load1=$(get_metric "$node" "node_load1")
    local load5=$(get_metric "$node" "node_load5")
    local load15=$(get_metric "$node" "node_load15")
    
    echo "$load1,$load5,$load15"
}

# Get network stats
get_network_stats() {
    local node="$1"
    
    # Get primary network interface (exclude lo, docker, etc.)
    local rx_bytes=$(get_metric "$node" "node_network_receive_bytes_total" | grep -v 'device="lo"' | head -1)
    local tx_bytes=$(get_metric "$node" "node_network_transmit_bytes_total" | grep -v 'device="lo"' | head -1)
    local rx_errors=$(get_metric "$node" "node_network_receive_errs_total" | grep -v 'device="lo"' | head -1)
    local tx_errors=$(get_metric "$node" "node_network_transmit_errs_total" | grep -v 'device="lo"' | head -1)
    
    echo "$rx_bytes,$tx_bytes,$rx_errors,$tx_errors"
}

# Test metrics for a single node
test_node_metrics() {
    local node="$1"
    local issues=()
    
    log_info "Testing metrics on node: $node"
    
    # Test CPU metrics
    local cpu_idle=$(calculate_cpu_usage "$node")
    if [[ "$cpu_idle" == "error" ]]; then
        issues+=("CPU metrics unavailable")
    else
        if (( $(echo "$cpu_idle < $CPU_IDLE_MIN" | bc -l) )); then
            issues+=("High CPU usage: ${cpu_idle}% idle")
        fi
    fi
    
    # Test memory metrics
    local mem_available=$(calculate_memory_usage "$node")
    if [[ "$mem_available" == "error" ]]; then
        issues+=("Memory metrics unavailable")
    else
        if (( $(echo "$mem_available < $MEM_AVAILABLE_MIN" | bc -l) )); then
            issues+=("Low memory: ${mem_available}% available")
        fi
    fi
    
    # Test disk metrics
    local disk_free=$(calculate_disk_usage "$node")
    if [[ "$disk_free" == "error" ]]; then
        issues+=("Disk metrics unavailable")
    else
        if (( $(echo "$disk_free < $DISK_FREE_MIN" | bc -l) )); then
            issues+=("Low disk space: ${disk_free}% free")
        fi
    fi
    
    # Get additional metrics
    local load=$(get_system_load "$node")
    local network=$(get_network_stats "$node")
    
    # Return results
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "{\"node\": \"$node\", "
        echo -n "\"cpu_idle_pct\": ${cpu_idle:-null}, "
        echo -n "\"mem_available_pct\": ${mem_available:-null}, "
        echo -n "\"disk_free_pct\": ${disk_free:-null}, "
        echo -n "\"load\": \"$load\", "
        echo -n "\"issues\": ["
        local first=true
        for issue in "${issues[@]}"; do
            if [[ "$first" == "false" ]]; then echo -n ", "; fi
            echo -n "\"$issue\""
            first=false
        done
        echo -n "]}"
    elif [[ "$OUTPUT_FORMAT" == "prometheus" ]]; then
        # Output in Prometheus format
        echo "# HELP k3s_node_cpu_idle_percent CPU idle percentage"
        echo "# TYPE k3s_node_cpu_idle_percent gauge"
        echo "k3s_node_cpu_idle_percent{node=\"$node\"} ${cpu_idle:-0}"
        echo "# HELP k3s_node_memory_available_percent Memory available percentage"
        echo "# TYPE k3s_node_memory_available_percent gauge"
        echo "k3s_node_memory_available_percent{node=\"$node\"} ${mem_available:-0}"
        echo "# HELP k3s_node_disk_free_percent Disk free percentage"
        echo "# TYPE k3s_node_disk_free_percent gauge"
        echo "k3s_node_disk_free_percent{node=\"$node\"} ${disk_free:-0}"
    else
        # Text format
        echo "  Node: $node"
        echo "  CPU Idle: ${cpu_idle}%"
        echo "  Memory Available: ${mem_available}%"
        echo "  Disk Free: ${disk_free}%"
        echo "  Load Average: $load"
        
        if [[ ${#issues[@]} -gt 0 ]]; then
            echo "  Issues:"
            for issue in "${issues[@]}"; do
                echo "    - $issue"
            done
        else
            echo "  Status: Healthy"
        fi
    fi
    
    return $([ ${#issues[@]} -eq 0 ] && echo 0 || echo 1)
}

# Aggregate metrics across all nodes
aggregate_metrics() {
    local total_cpu=0
    local total_mem=0
    local total_disk=0
    local node_count=0
    local unhealthy_nodes=0
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "{"
        echo "  \"nodes\": ["
    fi
    
    local first_node=true
    for node in "${TARGET_NODES[@]}"; do
        if [[ "$OUTPUT_FORMAT" == "json" ]] && [[ "$first_node" == "false" ]]; then
            echo ","
        fi
        
        if test_node_metrics "$node"; then
            ((node_count++))
        else
            ((unhealthy_nodes++))
        fi
        
        first_node=false
    done
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "  ],"
        echo "  \"summary\": {"
        echo "    \"total_nodes\": ${#TARGET_NODES[@]},"
        echo "    \"healthy_nodes\": $node_count,"
        echo "    \"unhealthy_nodes\": $unhealthy_nodes"
        echo "  }"
        echo "}"
    elif [[ "$OUTPUT_FORMAT" == "text" ]]; then
        echo
        echo "====================================="
        echo "Metrics Summary"
        echo "====================================="
        echo "Total nodes: ${#TARGET_NODES[@]}"
        echo "Healthy nodes: $node_count"
        echo "Unhealthy nodes: $unhealthy_nodes"
        echo "====================================="
    fi
    
    return $([ $unhealthy_nodes -eq 0 ] && echo 0 || echo 1)
}

# Main execution
main() {
    parse_args "$@"
    
    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        echo "====================================="
        echo "K3s Cluster Metrics Test"
        echo "====================================="
        echo
    fi
    
    # Detect nodes
    if ! detect_nodes; then
        log_error "Cannot detect nodes"
        exit 1
    fi
    
    # Test and aggregate metrics
    if ! aggregate_metrics; then
        if [[ "$OUTPUT_FORMAT" == "text" ]]; then
            log_error "Some nodes have metric issues"
        fi
        exit 1
    fi
    
    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        log_info "All metrics collected successfully"
    fi
}

# Run main function
main "$@"