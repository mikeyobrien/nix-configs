#!/usr/bin/env bash
# ABOUTME: Real-time k3s cluster health dashboard with continuous monitoring
# ABOUTME: Displays node status, resource usage, and pod health with alerts

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK_NODE_SCRIPT="$ROOT_DIR/tests/health/check-node.sh"
CHECK_CLUSTER_SCRIPT="$ROOT_DIR/tests/health/check-cluster.sh"

# Dashboard settings
REFRESH_INTERVAL="${REFRESH_INTERVAL:-10}"  # seconds
CONTINUOUS="${CONTINUOUS:-false}"
SHOW_PODS="${SHOW_PODS:-true}"
SHOW_RESOURCES="${SHOW_RESOURCES:-true}"
ALERT_SOUND="${ALERT_SOUND:-false}"
LOG_FILE="${LOG_FILE:-}"

# Node list (auto-detected or provided)
NODES=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Alert history
declare -A ALERT_HISTORY

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

Display real-time k3s cluster health dashboard.

OPTIONS:
    -n, --nodes LIST        Comma-separated list of nodes to monitor
    -r, --refresh SEC       Refresh interval (default: $REFRESH_INTERVAL seconds)
    -c, --continuous        Enable continuous monitoring mode
    -l, --log FILE          Log health data to file
    --no-pods               Hide pod status
    --no-resources          Hide resource usage
    --alert-sound           Enable sound alerts for critical issues
    -h, --help              Show this help message

ENVIRONMENT:
    REFRESH_INTERVAL        Dashboard refresh interval in seconds
    KUBECONFIG              Path to kubeconfig file

EXAMPLES:
    # One-time dashboard view
    $0

    # Continuous monitoring
    $0 --continuous

    # Monitor specific nodes
    $0 --nodes "10.10.20.11,10.10.20.12,10.10.20.13"

    # Fast refresh with logging
    $0 --continuous --refresh 5 --log /tmp/k3s-health.log

KEYBOARD SHORTCUTS (in continuous mode):
    q - Quit
    p - Toggle pod display
    r - Toggle resource display
    a - Toggle alert sound
    c - Clear screen and redraw

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
                IFS=',' read -ra NODES <<< "$2"
                shift 2
                ;;
            -r|--refresh)
                REFRESH_INTERVAL="$2"
                shift 2
                ;;
            -c|--continuous)
                CONTINUOUS=true
                shift
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            --no-pods)
                SHOW_PODS=false
                shift
                ;;
            --no-resources)
                SHOW_RESOURCES=false
                shift
                ;;
            --alert-sound)
                ALERT_SOUND=true
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

# Clear screen and move cursor to top
clear_screen() {
    printf '\033[2J\033[H'
}

# Get terminal size
get_terminal_size() {
    TERM_COLS=$(tput cols 2>/dev/null || echo 80)
    TERM_ROWS=$(tput lines 2>/dev/null || echo 24)
}

# Draw a horizontal line
draw_line() {
    local char="${1:--}"
    local width="${2:-$TERM_COLS}"
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

# Center text
center_text() {
    local text="$1"
    local width="${2:-$TERM_COLS}"
    local text_len=${#text}
    local pad_len=$(( (width - text_len) / 2 ))
    printf '%*s%s%*s' "$pad_len" '' "$text" "$pad_len" ''
}

# Auto-detect nodes
detect_nodes() {
    if [[ ${#NODES[@]} -eq 0 ]]; then
        log_info "Auto-detecting cluster nodes..."
        local node_list=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
        if [[ -n "$node_list" ]]; then
            IFS=' ' read -ra NODES <<< "$node_list"
            log_info "Detected nodes: ${NODES[*]}"
        else
            log_warning "Could not auto-detect nodes, will check local node only"
            NODES=("localhost")
        fi
    fi
}

# Play alert sound
play_alert_sound() {
    if [[ "$ALERT_SOUND" == "true" ]]; then
        # Try different methods to play a sound
        if command -v afplay &> /dev/null; then
            # macOS
            afplay /System/Library/Sounds/Ping.aiff 2>/dev/null &
        elif command -v paplay &> /dev/null; then
            # Linux with PulseAudio
            paplay /usr/share/sounds/freedesktop/stereo/bell.oga 2>/dev/null &
        elif command -v beep &> /dev/null; then
            # Simple beep
            beep 2>/dev/null &
        else
            # Terminal bell
            echo -e '\a'
        fi
    fi
}

# Check and track alerts
check_alert() {
    local alert_key="$1"
    local alert_active="$2"
    
    if [[ "$alert_active" == "true" ]]; then
        if [[ -z "${ALERT_HISTORY[$alert_key]:-}" ]]; then
            # New alert
            ALERT_HISTORY[$alert_key]=$(date +%s)
            play_alert_sound
            return 0
        fi
    else
        # Alert cleared
        unset ALERT_HISTORY[$alert_key] 2>/dev/null || true
    fi
    return 1
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [[ $bytes -gt 1024 ]] && [[ $unit -lt 4 ]]; do
        bytes=$((bytes / 1024))
        ((unit++))
    done
    
    echo "${bytes}${units[$unit]}"
}

# Get node health status
get_node_health() {
    local node="$1"
    local health_data
    
    if [[ "$node" == "localhost" ]]; then
        health_data=$("$CHECK_NODE_SCRIPT" --local --format json 2>/dev/null || echo '{"overall_status": "unknown"}')
    else
        health_data=$("$CHECK_NODE_SCRIPT" "$node" --format json 2>/dev/null || echo '{"overall_status": "unknown"}')
    fi
    
    echo "$health_data"
}

# Get cluster health status
get_cluster_health() {
    local health_data
    health_data=$("$CHECK_CLUSTER_SCRIPT" --format json 2>/dev/null || echo '{"overall_status": "unknown"}')
    echo "$health_data"
}

# Draw status icon
status_icon() {
    local status="$1"
    case "$status" in
        "healthy")
            echo -e "${GREEN}●${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}▲${NC}"
            ;;
        "critical")
            echo -e "${RED}✖${NC}"
            ;;
        *)
            echo -e "${DIM}?${NC}"
            ;;
    esac
}

# Draw header
draw_header() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    clear_screen
    echo -e "${BOLD}${CYAN}"
    center_text "K3s Cluster Health Dashboard"
    echo -e "${NC}"
    echo -e "${DIM}$timestamp${NC}"
    draw_line "="
    echo
}

# Draw node status section
draw_node_status() {
    echo -e "${BOLD}Node Status:${NC}"
    echo
    
    local all_healthy=true
    
    for node in "${NODES[@]}"; do
        local health_data=$(get_node_health "$node")
        local status=$(echo "$health_data" | jq -r '.overall_status // "unknown"')
        local cpu_usage=$(echo "$health_data" | jq -r '.cpu.usage // 0')
        local mem_usage=$(echo "$health_data" | jq -r '.memory.usage // 0')
        local disk_usage=$(echo "$health_data" | jq -r '.disk.usage // 0')
        
        # Check for alerts
        if [[ "$status" == "critical" ]]; then
            all_healthy=false
            check_alert "node_$node" "true"
        else
            check_alert "node_$node" "false"
        fi
        
        # Node line
        printf "  %-20s %s  CPU: %3d%%  MEM: %3d%%  DISK: %3d%%\n" \
            "$node" \
            "$(status_icon "$status")" \
            "$cpu_usage" \
            "$mem_usage" \
            "$disk_usage"
    done
    
    echo
    return $([ "$all_healthy" == "true" ] && echo 0 || echo 1)
}

# Draw cluster status section
draw_cluster_status() {
    local cluster_data=$(get_cluster_health)
    local overall_status=$(echo "$cluster_data" | jq -r '.overall_status // "unknown"')
    
    echo -e "${BOLD}Cluster Overview:${NC}"
    echo
    
    # Nodes
    local total_nodes=$(echo "$cluster_data" | jq -r '.nodes.total // 0')
    local ready_nodes=$(echo "$cluster_data" | jq -r '.nodes.ready // 0')
    local not_ready_nodes=$(echo "$cluster_data" | jq -r '.nodes.not_ready // 0')
    
    printf "  Nodes:       %d total, %d ready" "$total_nodes" "$ready_nodes"
    if [[ $not_ready_nodes -gt 0 ]]; then
        printf ", ${RED}%d not ready${NC}" "$not_ready_nodes"
        check_alert "cluster_nodes" "true"
    else
        check_alert "cluster_nodes" "false"
    fi
    echo
    
    # ETCD
    local etcd_status=$(echo "$cluster_data" | jq -r '.etcd.status // "not_applicable"')
    if [[ "$etcd_status" != "not_applicable" ]]; then
        local etcd_healthy=$(echo "$cluster_data" | jq -r '.etcd.healthy // 0')
        local etcd_total=$(echo "$cluster_data" | jq -r '.etcd.total // 0')
        printf "  ETCD:        %d/%d healthy\n" "$etcd_healthy" "$etcd_total"
    fi
    
    # Overall status
    echo
    printf "  Overall:     %s %s\n" "$(status_icon "$overall_status")" "$overall_status"
    echo
}

# Draw pod status section
draw_pod_status() {
    if [[ "$SHOW_PODS" != "true" ]]; then
        return
    fi
    
    local cluster_data=$(get_cluster_health)
    
    echo -e "${BOLD}Pod Status:${NC}"
    echo
    
    local total_pods=$(echo "$cluster_data" | jq -r '.pods.total // 0')
    local running_pods=$(echo "$cluster_data" | jq -r '.pods.running // 0')
    local pending_pods=$(echo "$cluster_data" | jq -r '.pods.pending // 0')
    local failed_pods=$(echo "$cluster_data" | jq -r '.pods.failed // 0')
    
    printf "  Total:       %d\n" "$total_pods"
    printf "  Running:     ${GREEN}%d${NC}\n" "$running_pods"
    
    if [[ $pending_pods -gt 0 ]]; then
        printf "  Pending:     ${YELLOW}%d${NC}\n" "$pending_pods"
    fi
    
    if [[ $failed_pods -gt 0 ]]; then
        printf "  Failed:      ${RED}%d${NC}\n" "$failed_pods"
        check_alert "pods_failed" "true"
    else
        check_alert "pods_failed" "false"
    fi
    
    echo
}

# Draw resource usage section
draw_resource_usage() {
    if [[ "$SHOW_RESOURCES" != "true" ]]; then
        return
    fi
    
    local cluster_data=$(get_cluster_health)
    
    echo -e "${BOLD}Resource Allocation:${NC}"
    echo
    
    local cpu_allocated=$(echo "$cluster_data" | jq -r '.resources.cpu_allocated_pct // 0')
    local mem_allocated=$(echo "$cluster_data" | jq -r '.resources.memory_allocated_pct // 0')
    
    # CPU bar
    printf "  CPU:  ["
    local cpu_bar_width=30
    local cpu_filled=$((cpu_allocated * cpu_bar_width / 100))
    for ((i=0; i<cpu_bar_width; i++)); do
        if [[ $i -lt $cpu_filled ]]; then
            if [[ $cpu_allocated -gt 80 ]]; then
                echo -ne "${RED}█${NC}"
            elif [[ $cpu_allocated -gt 60 ]]; then
                echo -ne "${YELLOW}█${NC}"
            else
                echo -ne "${GREEN}█${NC}"
            fi
        else
            echo -n "░"
        fi
    done
    printf "] %3d%%\n" "$cpu_allocated"
    
    # Memory bar
    printf "  MEM:  ["
    local mem_filled=$((mem_allocated * cpu_bar_width / 100))
    for ((i=0; i<cpu_bar_width; i++)); do
        if [[ $i -lt $mem_filled ]]; then
            if [[ $mem_allocated -gt 80 ]]; then
                echo -ne "${RED}█${NC}"
            elif [[ $mem_allocated -gt 60 ]]; then
                echo -ne "${YELLOW}█${NC}"
            else
                echo -ne "${GREEN}█${NC}"
            fi
        else
            echo -n "░"
        fi
    done
    printf "] %3d%%\n" "$mem_allocated"
    
    echo
}

# Draw alerts section
draw_alerts() {
    if [[ ${#ALERT_HISTORY[@]} -gt 0 ]]; then
        echo -e "${BOLD}${RED}Active Alerts:${NC}"
        echo
        for alert in "${!ALERT_HISTORY[@]}"; do
            local alert_time=${ALERT_HISTORY[$alert]}
            local duration=$(($(date +%s) - alert_time))
            printf "  ${RED}●${NC} %s (for %ds)\n" "$alert" "$duration"
        done
        echo
    fi
}

# Draw footer
draw_footer() {
    draw_line "-"
    if [[ "$CONTINUOUS" == "true" ]]; then
        echo -e "${DIM}Refreshing every ${REFRESH_INTERVAL}s | Press 'q' to quit${NC}"
    fi
}

# Log health data
log_health_data() {
    if [[ -n "$LOG_FILE" ]]; then
        local timestamp=$(date -Iseconds)
        local log_entry="{\"timestamp\": \"$timestamp\", \"nodes\": ["
        
        local first=true
        for node in "${NODES[@]}"; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                log_entry+=", "
            fi
            local health_data=$(get_node_health "$node")
            log_entry+="{\"node\": \"$node\", \"data\": $health_data}"
        done
        
        log_entry+="], \"cluster\": $(get_cluster_health)}"
        echo "$log_entry" >> "$LOG_FILE"
    fi
}

# Draw complete dashboard
draw_dashboard() {
    get_terminal_size
    draw_header
    draw_node_status
    draw_cluster_status
    draw_pod_status
    draw_resource_usage
    draw_alerts
    draw_footer
    log_health_data
}

# Handle keyboard input (non-blocking)
handle_input() {
    if read -r -t 0.1 -n 1 key; then
        case "$key" in
            q|Q)
                return 1
                ;;
            p|P)
                SHOW_PODS=$([ "$SHOW_PODS" == "true" ] && echo "false" || echo "true")
                ;;
            r|R)
                SHOW_RESOURCES=$([ "$SHOW_RESOURCES" == "true" ] && echo "false" || echo "true")
                ;;
            a|A)
                ALERT_SOUND=$([ "$ALERT_SOUND" == "true" ] && echo "false" || echo "true")
                ;;
            c|C)
                clear_screen
                ;;
        esac
    fi
    return 0
}

# Main execution
main() {
    parse_args "$@"
    
    # Check for required scripts
    if [[ ! -x "$CHECK_NODE_SCRIPT" ]]; then
        log_error "Node check script not found: $CHECK_NODE_SCRIPT"
        exit 1
    fi
    
    if [[ ! -x "$CHECK_CLUSTER_SCRIPT" ]]; then
        log_error "Cluster check script not found: $CHECK_CLUSTER_SCRIPT"
        exit 1
    fi
    
    # Auto-detect nodes
    detect_nodes
    
    # Set up terminal for continuous mode
    if [[ "$CONTINUOUS" == "true" ]]; then
        # Save terminal state
        tput smcup 2>/dev/null || true
        # Hide cursor
        tput civis 2>/dev/null || true
        # Disable input buffering
        stty -echo -icanon min 0 time 0 2>/dev/null || true
        
        # Trap to restore terminal on exit
        trap 'tput rmcup 2>/dev/null || true; tput cnorm 2>/dev/null || true; stty sane 2>/dev/null || true' EXIT INT TERM
    fi
    
    # Main loop
    while true; do
        draw_dashboard
        
        if [[ "$CONTINUOUS" != "true" ]]; then
            break
        fi
        
        # Wait for refresh interval, checking for input
        local elapsed=0
        while [[ $elapsed -lt $REFRESH_INTERVAL ]]; do
            if ! handle_input; then
                exit 0
            fi
            sleep 0.1
            elapsed=$(bc <<< "$elapsed + 0.1")
        done
    done
}

# Run main function
main "$@"