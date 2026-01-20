#!/usr/bin/env bash
# ABOUTME: Check overall k3s cluster health including all nodes and pods
# ABOUTME: Monitors cluster resources, etcd health, and workload status

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Cluster access
KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
KUBECTL="${KUBECTL:-kubectl}"

# Check settings
CHECK_ETCD="${CHECK_ETCD:-true}"
CHECK_PODS="${CHECK_PODS:-true}"
CHECK_SERVICES="${CHECK_SERVICES:-true}"
CHECK_DEPLOYMENTS="${CHECK_DEPLOYMENTS:-true}"
NAMESPACES="${NAMESPACES:-all}"  # all or space-separated list

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
Usage: $0 [OPTIONS]

Check k3s cluster health including all nodes, pods, and services.

OPTIONS:
    -k, --kubeconfig PATH   Path to kubeconfig (default: $KUBECONFIG)
    -n, --namespaces LIST   Namespaces to check (default: all)
    -f, --format FORMAT     Output format: text, json (default: $OUTPUT_FORMAT)
    -v, --verbose           Enable verbose output
    --no-etcd               Skip etcd health check
    --no-pods               Skip pod health check
    --no-services           Skip service health check
    --no-deployments        Skip deployment health check
    -h, --help              Show this help message

ENVIRONMENT:
    KUBECONFIG              Path to kubeconfig file
    KUBECTL                 kubectl command (default: kubectl)

EXAMPLES:
    # Check cluster health
    $0

    # Check specific namespaces
    $0 --namespaces "default kube-system"

    # JSON output for monitoring
    $0 --format json

    # Skip etcd check (for non-HA clusters)
    $0 --no-etcd

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
            -k|--kubeconfig)
                KUBECONFIG="$2"
                shift 2
                ;;
            -n|--namespaces)
                NAMESPACES="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-etcd)
                CHECK_ETCD=false
                shift
                ;;
            --no-pods)
                CHECK_PODS=false
                shift
                ;;
            --no-services)
                CHECK_SERVICES=false
                shift
                ;;
            --no-deployments)
                CHECK_DEPLOYMENTS=false
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

# Check kubectl access
check_kubectl_access() {
    log_debug "Checking kubectl access..."
    
    if ! command -v "$KUBECTL" &> /dev/null; then
        update_status "critical" "kubectl not found"
        return 1
    fi
    
    if [[ ! -f "$KUBECONFIG" ]] && [[ "$KUBECONFIG" != "${HOME}/.kube/config" ]]; then
        update_status "critical" "Kubeconfig not found: $KUBECONFIG"
        return 1
    fi
    
    if ! $KUBECTL cluster-info &> /dev/null; then
        update_status "critical" "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    return 0
}

# Check cluster nodes
check_nodes() {
    log_debug "Checking cluster nodes..."
    
    local nodes_json=$($KUBECTL get nodes -o json 2>/dev/null || echo '{"items":[]}')
    local total_nodes=$(echo "$nodes_json" | jq '.items | length')
    local ready_nodes=0
    local not_ready_nodes=0
    local node_issues=""
    
    while IFS= read -r node_data; do
        local node_name=$(echo "$node_data" | jq -r '.metadata.name')
        local conditions=$(echo "$node_data" | jq -r '.status.conditions[] | select(.type=="Ready") | .status')
        
        if [[ "$conditions" == "True" ]]; then
            ((ready_nodes++))
            log_debug "Node $node_name is Ready"
        else
            ((not_ready_nodes++))
            node_issues="${node_issues:+$node_issues, }$node_name"
        fi
    done < <(echo "$nodes_json" | jq -c '.items[]')
    
    if [[ $not_ready_nodes -gt 0 ]]; then
        update_status "critical" "Nodes not ready: $node_issues"
    elif [[ $total_nodes -eq 0 ]]; then
        update_status "critical" "No nodes found in cluster"
    else
        log_debug "All $total_nodes nodes are ready"
    fi
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "\"nodes\": {\"total\": $total_nodes, \"ready\": $ready_nodes, \"not_ready\": $not_ready_nodes}"
    else
        echo "=== Cluster Nodes ==="
        echo "Total nodes: $total_nodes"
        echo "Ready: $ready_nodes"
        echo "Not ready: $not_ready_nodes"
        if [[ -n "$node_issues" ]]; then
            echo "Issues: $node_issues"
        fi
        echo
    fi
}

# Check etcd health
check_etcd() {
    if [[ "$CHECK_ETCD" != "true" ]]; then
        log_debug "Skipping etcd check"
        return
    fi
    
    log_debug "Checking etcd health..."
    
    # Check if etcd pods exist
    local etcd_pods=$($KUBECTL get pods -n kube-system -l component=etcd -o json 2>/dev/null || echo '{"items":[]}')
    local etcd_count=$(echo "$etcd_pods" | jq '.items | length')
    
    if [[ $etcd_count -eq 0 ]]; then
        log_debug "No etcd pods found (single-node cluster?)"
        if [[ "$OUTPUT_FORMAT" == "json" ]]; then
            echo -n "\"etcd\": {\"status\": \"not_applicable\"}"
        else
            echo "=== ETCD Status ==="
            echo "Not applicable (single-node cluster)"
            echo
        fi
        return
    fi
    
    local healthy_members=0
    local unhealthy_members=0
    
    while IFS= read -r pod_data; do
        local pod_name=$(echo "$pod_data" | jq -r '.metadata.name')
        local pod_ready=$(echo "$pod_data" | jq -r '.status.conditions[] | select(.type=="Ready") | .status')
        
        if [[ "$pod_ready" == "True" ]]; then
            ((healthy_members++))
        else
            ((unhealthy_members++))
            update_status "critical" "ETCD member unhealthy: $pod_name"
        fi
    done < <(echo "$etcd_pods" | jq -c '.items[]')
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "\"etcd\": {\"total\": $etcd_count, \"healthy\": $healthy_members, \"unhealthy\": $unhealthy_members}"
    else
        echo "=== ETCD Status ==="
        echo "Total members: $etcd_count"
        echo "Healthy: $healthy_members"
        echo "Unhealthy: $unhealthy_members"
        echo
    fi
}

# Check pod health
check_pods() {
    if [[ "$CHECK_PODS" != "true" ]]; then
        log_debug "Skipping pod check"
        return
    fi
    
    log_debug "Checking pod health..."
    
    local namespace_filter=""
    if [[ "$NAMESPACES" != "all" ]]; then
        namespace_filter="-n $NAMESPACES"
    else
        namespace_filter="--all-namespaces"
    fi
    
    local pods_json=$($KUBECTL get pods $namespace_filter -o json 2>/dev/null || echo '{"items":[]}')
    local total_pods=$(echo "$pods_json" | jq '.items | length')
    local running_pods=0
    local pending_pods=0
    local failed_pods=0
    local pod_issues=""
    
    while IFS= read -r pod_data; do
        local pod_name=$(echo "$pod_data" | jq -r '.metadata.name')
        local pod_namespace=$(echo "$pod_data" | jq -r '.metadata.namespace')
        local pod_phase=$(echo "$pod_data" | jq -r '.status.phase')
        
        case "$pod_phase" in
            "Running"|"Succeeded")
                ((running_pods++))
                ;;
            "Pending")
                ((pending_pods++))
                log_debug "Pod pending: $pod_namespace/$pod_name"
                ;;
            "Failed"|"Unknown")
                ((failed_pods++))
                pod_issues="${pod_issues:+$pod_issues, }$pod_namespace/$pod_name"
                ;;
        esac
    done < <(echo "$pods_json" | jq -c '.items[]')
    
    if [[ $failed_pods -gt 0 ]]; then
        update_status "critical" "Failed pods: $pod_issues"
    elif [[ $pending_pods -gt 5 ]]; then
        update_status "warning" "Many pods pending: $pending_pods"
    fi
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "\"pods\": {\"total\": $total_pods, \"running\": $running_pods, \"pending\": $pending_pods, \"failed\": $failed_pods}"
    else
        echo "=== Pod Status ==="
        echo "Total pods: $total_pods"
        echo "Running: $running_pods"
        echo "Pending: $pending_pods"
        echo "Failed: $failed_pods"
        if [[ -n "$pod_issues" ]]; then
            echo "Failed pods: $pod_issues"
        fi
        echo
    fi
}

# Check service health
check_services() {
    if [[ "$CHECK_SERVICES" != "true" ]]; then
        log_debug "Skipping service check"
        return
    fi
    
    log_debug "Checking service health..."
    
    local namespace_filter=""
    if [[ "$NAMESPACES" != "all" ]]; then
        namespace_filter="-n $NAMESPACES"
    else
        namespace_filter="--all-namespaces"
    fi
    
    local services_json=$($KUBECTL get services $namespace_filter -o json 2>/dev/null || echo '{"items":[]}')
    local total_services=$(echo "$services_json" | jq '.items | length')
    local lb_pending=0
    
    while IFS= read -r svc_data; do
        local svc_name=$(echo "$svc_data" | jq -r '.metadata.name')
        local svc_namespace=$(echo "$svc_data" | jq -r '.metadata.namespace')
        local svc_type=$(echo "$svc_data" | jq -r '.spec.type')
        
        if [[ "$svc_type" == "LoadBalancer" ]]; then
            local ingress=$(echo "$svc_data" | jq -r '.status.loadBalancer.ingress // [] | length')
            if [[ $ingress -eq 0 ]]; then
                ((lb_pending++))
                log_debug "LoadBalancer pending: $svc_namespace/$svc_name"
            fi
        fi
    done < <(echo "$services_json" | jq -c '.items[]')
    
    if [[ $lb_pending -gt 0 ]]; then
        update_status "warning" "LoadBalancer services pending: $lb_pending"
    fi
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "\"services\": {\"total\": $total_services, \"loadbalancer_pending\": $lb_pending}"
    else
        echo "=== Service Status ==="
        echo "Total services: $total_services"
        if [[ $lb_pending -gt 0 ]]; then
            echo "LoadBalancer pending: $lb_pending"
        fi
        echo
    fi
}

# Check deployment health
check_deployments() {
    if [[ "$CHECK_DEPLOYMENTS" != "true" ]]; then
        log_debug "Skipping deployment check"
        return
    fi
    
    log_debug "Checking deployment health..."
    
    local namespace_filter=""
    if [[ "$NAMESPACES" != "all" ]]; then
        namespace_filter="-n $NAMESPACES"
    else
        namespace_filter="--all-namespaces"
    fi
    
    local deployments_json=$($KUBECTL get deployments $namespace_filter -o json 2>/dev/null || echo '{"items":[]}')
    local total_deployments=$(echo "$deployments_json" | jq '.items | length')
    local healthy_deployments=0
    local unhealthy_deployments=0
    local deployment_issues=""
    
    while IFS= read -r deploy_data; do
        local deploy_name=$(echo "$deploy_data" | jq -r '.metadata.name')
        local deploy_namespace=$(echo "$deploy_data" | jq -r '.metadata.namespace')
        local desired=$(echo "$deploy_data" | jq -r '.spec.replicas // 0')
        local available=$(echo "$deploy_data" | jq -r '.status.availableReplicas // 0')
        
        if [[ $available -eq $desired ]] && [[ $desired -gt 0 ]]; then
            ((healthy_deployments++))
        else
            ((unhealthy_deployments++))
            deployment_issues="${deployment_issues:+$deployment_issues, }$deploy_namespace/$deploy_name($available/$desired)"
        fi
    done < <(echo "$deployments_json" | jq -c '.items[]')
    
    if [[ $unhealthy_deployments -gt 0 ]]; then
        update_status "warning" "Unhealthy deployments: $deployment_issues"
    fi
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "\"deployments\": {\"total\": $total_deployments, \"healthy\": $healthy_deployments, \"unhealthy\": $unhealthy_deployments}"
    else
        echo "=== Deployment Status ==="
        echo "Total deployments: $total_deployments"
        echo "Healthy: $healthy_deployments"
        echo "Unhealthy: $unhealthy_deployments"
        if [[ -n "$deployment_issues" ]]; then
            echo "Issues: $deployment_issues"
        fi
        echo
    fi
}

# Check cluster resources
check_cluster_resources() {
    log_debug "Checking cluster resources..."
    
    local nodes_json=$($KUBECTL get nodes -o json 2>/dev/null || echo '{"items":[]}')
    local total_cpu_allocatable=0
    local total_cpu_requests=0
    local total_memory_allocatable=0
    local total_memory_requests=0
    
    # Calculate allocatable resources
    while IFS= read -r node_data; do
        local cpu=$(echo "$node_data" | jq -r '.status.allocatable.cpu // "0"' | sed 's/[^0-9]//g')
        local memory=$(echo "$node_data" | jq -r '.status.allocatable.memory // "0Ki"' | sed 's/Ki$//' | awk '{print int($1/1024)}')
        total_cpu_allocatable=$((total_cpu_allocatable + cpu))
        total_memory_allocatable=$((total_memory_allocatable + memory))
    done < <(echo "$nodes_json" | jq -c '.items[]')
    
    # Calculate requested resources
    local pods_json=$($KUBECTL get pods --all-namespaces -o json 2>/dev/null || echo '{"items":[]}')
    
    while IFS= read -r pod_data; do
        local containers=$(echo "$pod_data" | jq -c '.spec.containers[]')
        while IFS= read -r container; do
            local cpu_req=$(echo "$container" | jq -r '.resources.requests.cpu // "0"' | sed 's/m$//' | awk '{print int($1)}')
            local mem_req=$(echo "$container" | jq -r '.resources.requests.memory // "0Mi"' | sed 's/Mi$//' | awk '{print int($1)}')
            total_cpu_requests=$((total_cpu_requests + cpu_req))
            total_memory_requests=$((total_memory_requests + mem_req))
        done <<< "$containers"
    done < <(echo "$pods_json" | jq -c '.items[]')
    
    # Calculate usage percentages
    local cpu_usage_pct=0
    local memory_usage_pct=0
    
    if [[ $total_cpu_allocatable -gt 0 ]]; then
        cpu_usage_pct=$((total_cpu_requests * 100 / (total_cpu_allocatable * 1000)))
    fi
    
    if [[ $total_memory_allocatable -gt 0 ]]; then
        memory_usage_pct=$((total_memory_requests * 100 / total_memory_allocatable))
    fi
    
    if [[ $cpu_usage_pct -gt 80 ]]; then
        update_status "warning" "High CPU allocation: ${cpu_usage_pct}%"
    fi
    
    if [[ $memory_usage_pct -gt 80 ]]; then
        update_status "warning" "High memory allocation: ${memory_usage_pct}%"
    fi
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo -n "\"resources\": {\"cpu_allocated_pct\": $cpu_usage_pct, \"memory_allocated_pct\": $memory_usage_pct}"
    else
        echo "=== Cluster Resources ==="
        echo "CPU allocated: ${cpu_usage_pct}%"
        echo "Memory allocated: ${memory_usage_pct}%"
        echo
    fi
}

# Generate JSON output
generate_json_output() {
    echo "{"
    check_nodes
    echo ","
    check_etcd
    echo ","
    check_pods
    echo ","
    check_services
    echo ","
    check_deployments
    echo ","
    check_cluster_resources
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
    
    # Check kubectl access first
    if ! check_kubectl_access; then
        if [[ "$OUTPUT_FORMAT" == "json" ]]; then
            echo "{\"error\": \"Cannot access Kubernetes cluster\", \"overall_status\": \"critical\"}"
        else
            echo "Cannot access Kubernetes cluster. Check kubeconfig and connectivity."
        fi
        exit 2
    fi
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        generate_json_output
    else
        echo "====================================="
        echo "K3s Cluster Health Check"
        echo "====================================="
        echo
        
        check_nodes
        check_etcd
        check_pods
        check_services
        check_deployments
        check_cluster_resources
        
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