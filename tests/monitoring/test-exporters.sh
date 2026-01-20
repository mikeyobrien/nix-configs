#!/usr/bin/env bash
# ABOUTME: Test Prometheus exporters installation and functionality
# ABOUTME: Validates node exporter, kube-state-metrics, and custom exporters

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Test configuration
TEST_NAME="Prometheus Exporters Tests"
NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"
KUBE_STATE_PORT="${KUBE_STATE_PORT:-8080}"
TARGET_NODES=()  # Will be populated from args or auto-detected
TEST_TIMEOUT="${TEST_TIMEOUT:-30}"

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
Usage: $0 [OPTIONS]

Test Prometheus exporters on k3s cluster nodes.

OPTIONS:
    -n, --nodes LIST        Comma-separated list of nodes to test
    -p, --port PORT         Node exporter port (default: $NODE_EXPORTER_PORT)
    -k, --kube-port PORT    Kube-state-metrics port (default: $KUBE_STATE_PORT)
    -t, --timeout SEC       Test timeout (default: $TEST_TIMEOUT)
    -h, --help              Show this help message

ENVIRONMENT:
    NODE_EXPORTER_PORT      Port for node exporter metrics
    KUBE_STATE_PORT         Port for kube-state-metrics
    KUBECONFIG              Path to kubeconfig file

EXAMPLES:
    # Test exporters on all nodes
    $0

    # Test specific nodes
    $0 --nodes "10.10.20.11,10.10.20.12,10.10.20.13"

    # Test with custom ports
    $0 --port 9101 --kube-port 8081

EXPORTERS TESTED:
    - Prometheus Node Exporter (system metrics)
    - Kube-state-metrics (Kubernetes object metrics)
    - Custom application exporters (if configured)

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
            -k|--kube-port)
                KUBE_STATE_PORT="$2"
                shift 2
                ;;
            -t|--timeout)
                TEST_TIMEOUT="$2"
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

# Test node exporter installation
test_node_exporter_installed() {
    local test_name="Node exporter installation"
    test_start "$test_name"
    
    local installed_count=0
    local failed_nodes=()
    
    for node in "${TARGET_NODES[@]}"; do
        # Check if node exporter is running (via systemd or k8s)
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@$node" \
           "systemctl is-active prometheus-node-exporter || systemctl is-active node_exporter" >/dev/null 2>&1; then
            ((installed_count++))
            log_info "Node exporter active on $node (systemd)"
        elif kubectl get pods --all-namespaces -o wide | grep -q "node-exporter.*$node.*Running"; then
            ((installed_count++))
            log_info "Node exporter active on $node (kubernetes)"
        else
            failed_nodes+=("$node")
        fi
    done
    
    if [[ $installed_count -eq ${#TARGET_NODES[@]} ]]; then
        test_pass "$test_name (all ${#TARGET_NODES[@]} nodes)"
    else
        test_fail "$test_name" "Not installed on: ${failed_nodes[*]}"
        return 1
    fi
    
    return 0
}

# Test metrics endpoint accessibility
test_metrics_endpoint() {
    local test_name="Metrics endpoint accessibility"
    test_start "$test_name"
    
    local accessible_count=0
    local failed_nodes=()
    
    for node in "${TARGET_NODES[@]}"; do
        # Test HTTP endpoint
        if curl -sf -m "$TEST_TIMEOUT" "http://$node:$NODE_EXPORTER_PORT/metrics" >/dev/null 2>&1; then
            ((accessible_count++))
        else
            failed_nodes+=("$node")
        fi
    done
    
    if [[ $accessible_count -eq ${#TARGET_NODES[@]} ]]; then
        test_pass "$test_name (all nodes responding)"
    else
        test_fail "$test_name" "Not accessible on: ${failed_nodes[*]}"
        return 1
    fi
    
    return 0
}

# Test metric collection
test_metric_collection() {
    local test_name="Metric collection"
    test_start "$test_name"
    
    # Key metrics to check
    local required_metrics=(
        "node_cpu_seconds_total"
        "node_memory_MemTotal_bytes"
        "node_filesystem_size_bytes"
        "node_network_receive_bytes_total"
        "node_load1"
        "node_disk_io_time_seconds_total"
    )
    
    local all_metrics_found=true
    
    for node in "${TARGET_NODES[@]}"; do
        log_info "Checking metrics on $node..."
        
        # Get metrics from node
        local metrics=$(curl -sf -m "$TEST_TIMEOUT" "http://$node:$NODE_EXPORTER_PORT/metrics" 2>/dev/null || echo "")
        
        if [[ -z "$metrics" ]]; then
            test_fail "$test_name" "Could not fetch metrics from $node"
            return 1
        fi
        
        # Check for required metrics
        for metric in "${required_metrics[@]}"; do
            if ! echo "$metrics" | grep -q "^$metric{"; then
                log_warning "Metric $metric not found on $node"
                all_metrics_found=false
            fi
        done
    done
    
    if [[ "$all_metrics_found" == "true" ]]; then
        test_pass "$test_name (all required metrics present)"
    else
        test_fail "$test_name" "Some required metrics missing"
        return 1
    fi
    
    return 0
}

# Test metric values sanity
test_metric_values() {
    local test_name="Metric value sanity"
    test_start "$test_name"
    
    local issues=()
    
    for node in "${TARGET_NODES[@]}"; do
        # Get specific metric values
        local cpu_count=$(curl -sf "http://$node:$NODE_EXPORTER_PORT/metrics" 2>/dev/null | grep -E "^node_cpu_seconds_total.*mode=\"idle\"" | wc -l || echo 0)
        local mem_total=$(curl -sf "http://$node:$NODE_EXPORTER_PORT/metrics" 2>/dev/null | grep "^node_memory_MemTotal_bytes" | awk '{print $2}' || echo 0)
        
        # Sanity checks
        if [[ $cpu_count -lt 1 ]]; then
            issues+=("$node: No CPU metrics")
        fi
        
        if [[ $mem_total -lt 1073741824 ]]; then  # Less than 1GB
            issues+=("$node: Memory too low or not reported")
        fi
    done
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Issues found: ${issues[*]}"
        return 1
    fi
    
    return 0
}

# Test kube-state-metrics
test_kube_state_metrics() {
    local test_name="Kube-state-metrics"
    test_start "$test_name"
    
    # Check if kube-state-metrics is deployed
    local ksm_pod=$(kubectl get pods --all-namespaces | grep "kube-state-metrics.*Running" | head -1 | awk '{print $2}')
    
    if [[ -z "$ksm_pod" ]]; then
        log_warning "Kube-state-metrics not deployed"
        test_pass "$test_name (not deployed)"
        return 0
    fi
    
    # Get the service endpoint
    local ksm_namespace=$(kubectl get pods --all-namespaces | grep "kube-state-metrics.*Running" | head -1 | awk '{print $1}')
    local ksm_service=$(kubectl get svc -n "$ksm_namespace" | grep "kube-state-metrics" | head -1 | awk '{print $1}')
    
    if [[ -z "$ksm_service" ]]; then
        test_fail "$test_name" "Service not found"
        return 1
    fi
    
    # Test metrics endpoint via port-forward
    kubectl port-forward -n "$ksm_namespace" "svc/$ksm_service" "$KUBE_STATE_PORT:$KUBE_STATE_PORT" >/dev/null 2>&1 &
    local pf_pid=$!
    
    sleep 3
    
    # Check metrics
    if curl -sf "http://localhost:$KUBE_STATE_PORT/metrics" | grep -q "kube_node_info"; then
        test_pass "$test_name (metrics available)"
        kill $pf_pid 2>/dev/null || true
        return 0
    else
        test_fail "$test_name" "Metrics not accessible"
        kill $pf_pid 2>/dev/null || true
        return 1
    fi
}

# Test custom exporters
test_custom_exporters() {
    local test_name="Custom exporters"
    test_start "$test_name"
    
    # Look for custom exporters (e.g., k3s metrics)
    local custom_exporters=$(kubectl get pods --all-namespaces -o wide | grep -E "exporter|metrics" | grep -v "node-exporter\|kube-state-metrics" || echo "")
    
    if [[ -z "$custom_exporters" ]]; then
        log_info "No custom exporters found"
        test_pass "$test_name (none configured)"
        return 0
    fi
    
    # Test each custom exporter
    local working_exporters=0
    local total_exporters=$(echo "$custom_exporters" | wc -l)
    
    while read -r exporter; do
        local pod_name=$(echo "$exporter" | awk '{print $2}')
        local namespace=$(echo "$exporter" | awk '{print $1}')
        
        log_info "Testing custom exporter: $namespace/$pod_name"
        
        # Check if pod has metrics endpoint
        if kubectl exec -n "$namespace" "$pod_name" -- wget -O- -q http://localhost:9090/metrics >/dev/null 2>&1 || \
           kubectl exec -n "$namespace" "$pod_name" -- curl -sf http://localhost:8080/metrics >/dev/null 2>&1; then
            ((working_exporters++))
        fi
    done <<< "$custom_exporters"
    
    if [[ $working_exporters -eq $total_exporters ]]; then
        test_pass "$test_name ($working_exporters exporters working)"
    else
        test_fail "$test_name" "Only $working_exporters/$total_exporters working"
        return 1
    fi
    
    return 0
}

# Test metrics scraping configuration
test_scrape_configs() {
    local test_name="Prometheus scrape configs"
    test_start "$test_name"
    
    # Check if Prometheus is deployed
    local prom_pod=$(kubectl get pods --all-namespaces | grep "prometheus.*Running" | grep -v "operator\|alertmanager" | head -1 || echo "")
    
    if [[ -z "$prom_pod" ]]; then
        log_warning "Prometheus not deployed, skipping scrape config test"
        test_pass "$test_name (Prometheus not deployed)"
        return 0
    fi
    
    local prom_namespace=$(echo "$prom_pod" | awk '{print $1}')
    local prom_name=$(echo "$prom_pod" | awk '{print $2}')
    
    # Check Prometheus targets
    kubectl port-forward -n "$prom_namespace" "$prom_name" 9090:9090 >/dev/null 2>&1 &
    local pf_pid=$!
    
    sleep 3
    
    # Query Prometheus targets API
    local targets=$(curl -sf "http://localhost:9090/api/v1/targets" | jq -r '.data.activeTargets[] | .labels.job' | sort -u || echo "")
    
    kill $pf_pid 2>/dev/null || true
    
    if echo "$targets" | grep -q "node"; then
        test_pass "$test_name (node job configured)"
    else
        test_fail "$test_name" "Node exporter job not found in Prometheus"
        return 1
    fi
    
    return 0
}

# Test metric persistence
test_metric_persistence() {
    local test_name="Metric persistence"
    test_start "$test_name"
    
    # Pick a node to test
    local test_node="${TARGET_NODES[0]}"
    
    # Get initial metric value
    local metric_name="node_boot_time_seconds"
    local initial_value=$(curl -sf "http://$test_node:$NODE_EXPORTER_PORT/metrics" | grep "^$metric_name " | awk '{print $2}' || echo "")
    
    if [[ -z "$initial_value" ]]; then
        test_fail "$test_name" "Could not get initial metric value"
        return 1
    fi
    
    log_info "Initial $metric_name: $initial_value"
    
    # Wait and check again
    sleep 5
    
    local second_value=$(curl -sf "http://$test_node:$NODE_EXPORTER_PORT/metrics" | grep "^$metric_name " | awk '{print $2}' || echo "")
    
    # Boot time should remain constant
    if [[ "$initial_value" == "$second_value" ]]; then
        test_pass "$test_name (metrics stable)"
    else
        test_fail "$test_name" "Metric value changed unexpectedly"
        return 1
    fi
    
    return 0
}

# Test exporter resource usage
test_resource_usage() {
    local test_name="Exporter resource usage"
    test_start "$test_name"
    
    local high_usage_nodes=()
    
    for node in "${TARGET_NODES[@]}"; do
        # Check CPU usage of node exporter process
        local cpu_usage=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@$node" \
            "ps aux | grep -E 'node_exporter|prometheus-node-exporter' | grep -v grep | awk '{print \$3}'" 2>/dev/null || echo "0")
        
        # Check memory usage (RSS in KB)
        local mem_usage=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@$node" \
            "ps aux | grep -E 'node_exporter|prometheus-node-exporter' | grep -v grep | awk '{print \$6}'" 2>/dev/null || echo "0")
        
        # Convert to MB
        mem_usage=$((mem_usage / 1024))
        
        # Check thresholds (5% CPU, 100MB RAM)
        if (( $(echo "$cpu_usage > 5" | bc -l) )); then
            high_usage_nodes+=("$node: CPU ${cpu_usage}%")
        fi
        
        if [[ $mem_usage -gt 100 ]]; then
            high_usage_nodes+=("$node: Memory ${mem_usage}MB")
        fi
    done
    
    if [[ ${#high_usage_nodes[@]} -eq 0 ]]; then
        test_pass "$test_name (resource usage normal)"
    else
        test_fail "$test_name" "High usage on: ${high_usage_nodes[*]}"
        return 1
    fi
    
    return 0
}

# Summary report
print_summary() {
    echo
    echo "====================================="
    echo "Exporter Test Summary"
    echo "====================================="
    echo "Nodes tested: ${#TARGET_NODES[@]}"
    echo "Total tests: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo "====================================="
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_info "All exporter tests passed!"
        return 0
    else
        log_error "Some exporter tests failed"
        return 1
    fi
}

# Main execution
main() {
    parse_args "$@"
    
    echo "====================================="
    echo "$TEST_NAME"
    echo "====================================="
    echo
    
    # Detect nodes
    if ! detect_nodes; then
        log_error "Cannot detect nodes"
        exit 1
    fi
    
    # Run tests in order
    local tests=(
        "test_node_exporter_installed"
        "test_metrics_endpoint"
        "test_metric_collection"
        "test_metric_values"
        "test_kube_state_metrics"
        "test_custom_exporters"
        "test_scrape_configs"
        "test_metric_persistence"
        "test_resource_usage"
    )
    
    for test in "${tests[@]}"; do
        if ! $test; then
            log_warning "Test failed, continuing with remaining tests..."
        fi
        echo
    done
    
    # Print summary and exit
    print_summary
}

# Run main function
main "$@"