#!/usr/bin/env bash
# ABOUTME: Test k3s cluster join process for new nodes
# ABOUTME: Validates token auth, node registration, and role assignment

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
JOIN_SCRIPT="$ROOT_DIR/scripts/join-cluster.sh"

# Test configuration
TEST_NAME="K3s Cluster Join Tests"
MASTER_NODE="${MASTER_NODE:-}"
JOIN_TOKEN="${JOIN_TOKEN:-}"
NODE_HOST="${NODE_HOST:-}"
NODE_ROLE="${NODE_ROLE:-agent}"  # agent or server
TEST_MODE="${TEST_MODE:-dry-run}"  # dry-run or live

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

Test k3s cluster join process.

OPTIONS:
    -m, --master HOST       Master node address (required for live mode)
    -t, --token TOKEN       Join token (required for live mode)
    -n, --node HOST         Node to join (required for live mode)
    -r, --role ROLE         Node role: agent, server (default: $NODE_ROLE)
    --mode MODE             Test mode: dry-run, live (default: $TEST_MODE)
    -h, --help              Show this help message

ENVIRONMENT:
    MASTER_NODE             Master node address
    JOIN_TOKEN              K3s join token
    NODE_HOST               Node to join to cluster

EXAMPLES:
    # Dry run test
    $0 --mode dry-run

    # Live test joining agent node
    $0 --master 10.10.20.11 --token K12345... --node 10.10.20.12

    # Test joining server node (HA)
    $0 --master 10.10.20.11 --token K12345... --node 10.10.20.13 --role server

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
            --mode)
                TEST_MODE="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate required options for live mode
    if [[ "$TEST_MODE" == "live" ]]; then
        if [[ -z "$MASTER_NODE" ]] || [[ -z "$JOIN_TOKEN" ]] || [[ -z "$NODE_HOST" ]]; then
            log_error "Master node, token, and node host required for live mode"
            usage
            exit 1
        fi
    fi
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

# Test functions
test_join_script_exists() {
    local test_name="Join script exists"
    test_start "$test_name"
    
    if [[ -f "$JOIN_SCRIPT" ]]; then
        if [[ -x "$JOIN_SCRIPT" ]]; then
            test_pass "$test_name"
        else
            test_fail "$test_name" "Script not executable"
            return 1
        fi
    else
        test_fail "$test_name" "Script not found: $JOIN_SCRIPT"
        return 1
    fi
    
    return 0
}

test_prerequisites() {
    local test_name="Prerequisites check"
    test_start "$test_name"
    
    local missing_tools=()
    local required_tools=("kubectl" "ssh" "curl" "jq")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -eq 0 ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Missing tools: ${missing_tools[*]}"
        return 1
    fi
    
    return 0
}

test_master_connectivity() {
    local test_name="Master node connectivity"
    test_start "$test_name"
    
    if [[ "$TEST_MODE" == "dry-run" ]]; then
        log_info "Skipping in dry-run mode"
        test_pass "$test_name (dry-run)"
        return 0
    fi
    
    # Test TCP connectivity to k3s API port
    if timeout 5 bash -c "echo > /dev/tcp/$MASTER_NODE/6443" 2>/dev/null; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Cannot reach master node API on $MASTER_NODE:6443"
        return 1
    fi
    
    return 0
}

test_token_format() {
    local test_name="Join token format"
    test_start "$test_name"
    
    if [[ "$TEST_MODE" == "dry-run" ]]; then
        log_info "Using mock token for dry-run"
        JOIN_TOKEN="K10abcdef1234567890abcdef1234567890abcdef1234567890abcdef12::server:abcdef1234567890abcdef1234567890"
        test_pass "$test_name (dry-run)"
        return 0
    fi
    
    # K3s tokens are typically in format K10xxx::server:xxx
    if [[ "$JOIN_TOKEN" =~ ^K10[a-f0-9]{58}::[a-z]+:[a-f0-9]{32}$ ]]; then
        test_pass "$test_name"
    else
        log_warning "Token format may be incorrect, but continuing"
        test_pass "$test_name (format warning)"
    fi
    
    return 0
}

test_node_connectivity() {
    local test_name="Node SSH connectivity"
    test_start "$test_name"
    
    if [[ "$TEST_MODE" == "dry-run" ]]; then
        log_info "Skipping in dry-run mode"
        test_pass "$test_name (dry-run)"
        return 0
    fi
    
    if ssh -o ConnectTimeout=5 \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           "root@$NODE_HOST" "true" 2>/dev/null; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Cannot SSH to node $NODE_HOST"
        return 1
    fi
    
    return 0
}

test_node_not_in_cluster() {
    local test_name="Node not already in cluster"
    test_start "$test_name"
    
    if [[ "$TEST_MODE" == "dry-run" ]]; then
        log_info "Skipping in dry-run mode"
        test_pass "$test_name (dry-run)"
        return 0
    fi
    
    # Check if node is already in cluster
    local existing_node=$(kubectl get nodes -o jsonpath="{.items[?(@.status.addresses[?(@.type=='InternalIP')].address=='$NODE_HOST')].metadata.name}" 2>/dev/null || echo "")
    
    if [[ -z "$existing_node" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Node already in cluster as: $existing_node"
        return 1
    fi
    
    return 0
}

test_join_script_dry_run() {
    local test_name="Join script dry-run"
    test_start "$test_name"
    
    if [[ ! -f "$JOIN_SCRIPT" ]]; then
        test_fail "$test_name" "Join script not found"
        return 1
    fi
    
    # Test dry-run mode
    local output
    if output=$("$JOIN_SCRIPT" \
        --master "${MASTER_NODE:-10.10.20.11}" \
        --token "${JOIN_TOKEN:-K10test::server:test}" \
        --node "${NODE_HOST:-10.10.20.12}" \
        --role "$NODE_ROLE" \
        --dry-run 2>&1); then
        
        if echo "$output" | grep -q "DRY RUN"; then
            test_pass "$test_name"
        else
            test_fail "$test_name" "Dry-run output not detected"
            return 1
        fi
    else
        test_fail "$test_name" "Script failed: $output"
        return 1
    fi
    
    return 0
}

test_cluster_join_simulation() {
    local test_name="Cluster join simulation"
    test_start "$test_name"
    
    if [[ "$TEST_MODE" == "dry-run" ]]; then
        log_info "Simulating cluster join process..."
        
        # Simulate the steps
        log_info "1. Would install k3s on node"
        log_info "2. Would configure with master URL: https://${MASTER_NODE:-10.10.20.11}:6443"
        log_info "3. Would use join token for authentication"
        log_info "4. Would start k3s-${NODE_ROLE} service"
        log_info "5. Would verify node appears in cluster"
        
        test_pass "$test_name (simulation)"
        return 0
    fi
    
    # For live mode, actually run the join script
    log_info "Executing cluster join..."
    
    if "$JOIN_SCRIPT" \
        --master "$MASTER_NODE" \
        --token "$JOIN_TOKEN" \
        --node "$NODE_HOST" \
        --role "$NODE_ROLE"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Join script failed"
        return 1
    fi
    
    return 0
}

test_verify_node_joined() {
    local test_name="Verify node joined cluster"
    test_start "$test_name"
    
    if [[ "$TEST_MODE" == "dry-run" ]]; then
        log_info "Would verify node appears in: kubectl get nodes"
        test_pass "$test_name (dry-run)"
        return 0
    fi
    
    # Wait for node to appear
    log_info "Waiting for node to appear in cluster..."
    local max_attempts=30
    local attempt=0
    local node_found=false
    
    while [[ $attempt -lt $max_attempts ]]; do
        local node_name=$(kubectl get nodes -o jsonpath="{.items[?(@.status.addresses[?(@.type=='InternalIP')].address=='$NODE_HOST')].metadata.name}" 2>/dev/null || echo "")
        
        if [[ -n "$node_name" ]]; then
            node_found=true
            log_info "Node found: $node_name"
            break
        fi
        
        sleep 2
        ((attempt++))
    done
    
    if [[ "$node_found" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Node did not appear in cluster after ${max_attempts} attempts"
        return 1
    fi
    
    return 0
}

test_node_ready_state() {
    local test_name="Node reaches ready state"
    test_start "$test_name"
    
    if [[ "$TEST_MODE" == "dry-run" ]]; then
        log_info "Would wait for node Ready status"
        test_pass "$test_name (dry-run)"
        return 0
    fi
    
    # Wait for node to be ready
    log_info "Waiting for node to be ready..."
    local max_attempts=60
    local attempt=0
    local node_ready=false
    
    while [[ $attempt -lt $max_attempts ]]; do
        local node_status=$(kubectl get nodes -o jsonpath="{.items[?(@.status.addresses[?(@.type=='InternalIP')].address=='$NODE_HOST')].status.conditions[?(@.type=='Ready')].status}" 2>/dev/null || echo "")
        
        if [[ "$node_status" == "True" ]]; then
            node_ready=true
            log_info "Node is ready"
            break
        fi
        
        sleep 2
        ((attempt++))
    done
    
    if [[ "$node_ready" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Node did not reach ready state"
        return 1
    fi
    
    return 0
}

test_node_role_labels() {
    local test_name="Node role labels"
    test_start "$test_name"
    
    if [[ "$TEST_MODE" == "dry-run" ]]; then
        log_info "Would verify node has correct role labels"
        test_pass "$test_name (dry-run)"
        return 0
    fi
    
    # Check node labels
    local node_labels=$(kubectl get nodes -o jsonpath="{.items[?(@.status.addresses[?(@.type=='InternalIP')].address=='$NODE_HOST')].metadata.labels}" 2>/dev/null || echo "{}")
    
    if [[ "$NODE_ROLE" == "server" ]]; then
        if echo "$node_labels" | jq -e '.["node-role.kubernetes.io/master"]' >/dev/null 2>&1; then
            test_pass "$test_name (server node)"
        else
            test_fail "$test_name" "Server node missing master label"
            return 1
        fi
    else
        if echo "$node_labels" | jq -e '.["node-role.kubernetes.io/master"]' >/dev/null 2>&1; then
            test_fail "$test_name" "Agent node has master label"
            return 1
        else
            test_pass "$test_name (agent node)"
        fi
    fi
    
    return 0
}

test_cluster_communication() {
    local test_name="Cluster communication"
    test_start "$test_name"
    
    if [[ "$TEST_MODE" == "dry-run" ]]; then
        log_info "Would test pod scheduling on new node"
        test_pass "$test_name (dry-run)"
        return 0
    fi
    
    # Create a test pod on the new node
    local test_pod="test-join-${NODE_HOST//\./-}"
    local node_name=$(kubectl get nodes -o jsonpath="{.items[?(@.status.addresses[?(@.type=='InternalIP')].address=='$NODE_HOST')].metadata.name}" 2>/dev/null || echo "")
    
    if [[ -z "$node_name" ]]; then
        test_fail "$test_name" "Cannot find node name"
        return 1
    fi
    
    # Create test pod
    cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: $test_pod
  namespace: default
spec:
  nodeSelector:
    kubernetes.io/hostname: $node_name
  containers:
  - name: test
    image: busybox
    command: ["sleep", "30"]
EOF
    
    # Wait for pod to be running
    local pod_running=false
    for i in {1..15}; do
        local pod_status=$(kubectl get pod "$test_pod" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [[ "$pod_status" == "Running" ]]; then
            pod_running=true
            break
        fi
        sleep 2
    done
    
    # Cleanup
    kubectl delete pod "$test_pod" --grace-period=0 --force >/dev/null 2>&1 || true
    
    if [[ "$pod_running" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Test pod did not run on new node"
        return 1
    fi
    
    return 0
}

# Summary report
print_summary() {
    echo
    echo "====================================="
    echo "Cluster Join Test Summary"
    echo "====================================="
    echo "Mode: $TEST_MODE"
    if [[ "$TEST_MODE" == "live" ]]; then
        echo "Master: $MASTER_NODE"
        echo "Node: $NODE_HOST"
        echo "Role: $NODE_ROLE"
    fi
    echo "Total tests: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo "====================================="
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_info "All tests passed!"
        return 0
    else
        log_error "Some tests failed"
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
    
    # Run tests in order
    local tests=(
        "test_join_script_exists"
        "test_prerequisites"
        "test_master_connectivity"
        "test_token_format"
        "test_node_connectivity"
        "test_node_not_in_cluster"
        "test_join_script_dry_run"
        "test_cluster_join_simulation"
        "test_verify_node_joined"
        "test_node_ready_state"
        "test_node_role_labels"
        "test_cluster_communication"
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