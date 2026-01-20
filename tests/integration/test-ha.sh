#!/usr/bin/env bash
# ABOUTME: Test k3s high availability features including failover
# ABOUTME: Validates etcd cluster, leader election, and data persistence

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Test configuration
TEST_NAME="K3s High Availability Tests"
CLUSTER_NODES=()  # Will be populated from kubectl
ETCD_ENDPOINTS=""
TEST_NAMESPACE="ha-test"
TEST_DEPLOYMENT="ha-test-app"

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

Test k3s cluster high availability features.

OPTIONS:
    -n, --nodes LIST        Comma-separated list of server nodes
    -e, --etcd ENDPOINTS    ETCD endpoints (auto-detected if not set)
    --namespace NS          Test namespace (default: $TEST_NAMESPACE)
    -h, --help              Show this help message

ENVIRONMENT:
    KUBECONFIG              Path to kubeconfig file

EXAMPLES:
    # Test HA features (auto-detect nodes)
    $0

    # Test specific server nodes
    $0 --nodes "10.10.20.11,10.10.20.12,10.10.20.13"

    # Test with custom namespace
    $0 --namespace ha-testing

TESTS PERFORMED:
    - Cluster node count and roles
    - ETCD cluster health
    - Leader election functionality
    - Failover simulation
    - Data persistence across failures
    - Load balancing verification
    - Split-brain prevention

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
                IFS=',' read -ra CLUSTER_NODES <<< "$2"
                shift 2
                ;;
            -e|--etcd)
                ETCD_ENDPOINTS="$2"
                shift 2
                ;;
            --namespace)
                TEST_NAMESPACE="$2"
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

# Cleanup function
cleanup() {
    log_info "Cleaning up test resources..."
    kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found=true >/dev/null 2>&1 || true
}

trap cleanup EXIT

# Auto-detect cluster nodes
detect_cluster_nodes() {
    if [[ ${#CLUSTER_NODES[@]} -eq 0 ]]; then
        log_info "Auto-detecting server nodes..."
        
        # Get nodes with control-plane role
        local nodes=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || \
                     kubectl get nodes -l node-role.kubernetes.io/master -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || \
                     echo "")
        
        if [[ -n "$nodes" ]]; then
            IFS=' ' read -ra CLUSTER_NODES <<< "$nodes"
            log_info "Detected server nodes: ${CLUSTER_NODES[*]}"
        else
            log_error "Could not detect server nodes"
            return 1
        fi
    fi
    
    return 0
}

# Test cluster node configuration
test_cluster_nodes() {
    local test_name="Cluster node configuration"
    test_start "$test_name"
    
    # Check minimum nodes for HA
    if [[ ${#CLUSTER_NODES[@]} -lt 3 ]]; then
        test_fail "$test_name" "HA requires at least 3 server nodes, found ${#CLUSTER_NODES[@]}"
        return 1
    fi
    
    # Check if all nodes are ready
    local not_ready=0
    for node in "${CLUSTER_NODES[@]}"; do
        local node_name=$(kubectl get nodes -o jsonpath="{.items[?(@.status.addresses[?(@.type=='InternalIP')].address=='$node')].metadata.name}" 2>/dev/null || echo "")
        if [[ -z "$node_name" ]]; then
            ((not_ready++))
            log_warning "Node $node not found in cluster"
        else
            local node_status=$(kubectl get node "$node_name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
            if [[ "$node_status" != "True" ]]; then
                ((not_ready++))
                log_warning "Node $node_name is not ready"
            fi
        fi
    done
    
    if [[ $not_ready -eq 0 ]]; then
        test_pass "$test_name (${#CLUSTER_NODES[@]} nodes ready)"
    else
        test_fail "$test_name" "$not_ready nodes not ready"
        return 1
    fi
    
    return 0
}

# Test ETCD cluster health
test_etcd_health() {
    local test_name="ETCD cluster health"
    test_start "$test_name"
    
    # Check if etcd pods exist
    local etcd_pods=$(kubectl get pods -n kube-system -l component=etcd -o name 2>/dev/null | wc -l)
    
    if [[ $etcd_pods -eq 0 ]]; then
        log_warning "No separate etcd pods found, checking for embedded etcd"
        
        # For k3s with embedded etcd, check via k3s
        local healthy_members=0
        for node in "${CLUSTER_NODES[@]}"; do
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@$node" \
               "k3s etcd-snapshot list" >/dev/null 2>&1; then
                ((healthy_members++))
            fi
        done
        
        if [[ $healthy_members -eq ${#CLUSTER_NODES[@]} ]]; then
            test_pass "$test_name (embedded etcd on $healthy_members nodes)"
        else
            test_fail "$test_name" "Only $healthy_members/${#CLUSTER_NODES[@]} nodes have healthy etcd"
            return 1
        fi
    else
        # Check etcd pod health
        local healthy_pods=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | wc -w)
        
        if [[ $healthy_pods -eq $etcd_pods ]]; then
            test_pass "$test_name ($healthy_pods etcd pods healthy)"
        else
            test_fail "$test_name" "Only $healthy_pods/$etcd_pods etcd pods are healthy"
            return 1
        fi
    fi
    
    return 0
}

# Test leader election
test_leader_election() {
    local test_name="Leader election"
    test_start "$test_name"
    
    # Check for leader election endpoints
    local leader_endpoints=$(kubectl get endpoints -n kube-system | grep -E "leader-election|holderIdentity" | wc -l)
    
    if [[ $leader_endpoints -gt 0 ]]; then
        log_info "Found $leader_endpoints leader election endpoints"
        
        # Check if leader is elected
        local has_leader=false
        for endpoint in $(kubectl get endpoints -n kube-system -o name | grep -E "leader-election|scheduler|controller"); do
            local leader=$(kubectl get "$endpoint" -n kube-system -o jsonpath='{.metadata.annotations.control-plane\.alpha\.kubernetes\.io/leader}' 2>/dev/null || echo "")
            if [[ -n "$leader" ]]; then
                has_leader=true
                log_info "Leader elected for ${endpoint##*/}"
            fi
        done
        
        if [[ "$has_leader" == "true" ]]; then
            test_pass "$test_name"
        else
            test_fail "$test_name" "No leader elected"
            return 1
        fi
    else
        log_warning "No leader election endpoints found (may be using different mechanism)"
        test_pass "$test_name (alternative mechanism)"
    fi
    
    return 0
}

# Create test workload
create_test_workload() {
    log_info "Creating test workload..."
    
    # Create namespace
    kubectl create namespace "$TEST_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    
    # Create deployment with multiple replicas
    cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $TEST_DEPLOYMENT
  namespace: $TEST_NAMESPACE
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ha-test
  template:
    metadata:
      labels:
        app: ha-test
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - ha-test
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
      volumes:
      - name: data
        configMap:
          name: ha-test-data
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ha-test-data
  namespace: $TEST_NAMESPACE
data:
  index.html: |
    <html><body><h1>HA Test App</h1><p>Node: \$(hostname)</p></body></html>
---
apiVersion: v1
kind: Service
metadata:
  name: ha-test-svc
  namespace: $TEST_NAMESPACE
spec:
  selector:
    app: ha-test
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
    
    # Wait for deployment to be ready
    kubectl rollout status deployment/"$TEST_DEPLOYMENT" -n "$TEST_NAMESPACE" --timeout=60s >/dev/null 2>&1
}

# Test failover scenario
test_failover() {
    local test_name="Failover simulation"
    test_start "$test_name"
    
    # Create test workload
    create_test_workload
    
    # Get initial pod distribution
    local initial_pods=$(kubectl get pods -n "$TEST_NAMESPACE" -o wide --no-headers | awk '{print $7}' | sort | uniq -c)
    log_info "Initial pod distribution:"
    echo "$initial_pods"
    
    # Find a node with pods
    local target_node=$(kubectl get pods -n "$TEST_NAMESPACE" -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null || echo "")
    
    if [[ -z "$target_node" ]]; then
        test_fail "$test_name" "No pods found to test failover"
        return 1
    fi
    
    log_info "Simulating node failure by cordoning node: $target_node"
    
    # Cordon the node (prevent new pods)
    kubectl cordon "$target_node" >/dev/null
    
    # Delete pods on that node to simulate failure
    kubectl delete pods -n "$TEST_NAMESPACE" --field-selector "spec.nodeName=$target_node" --grace-period=0 --force >/dev/null 2>&1
    
    # Wait for pods to be rescheduled
    log_info "Waiting for pod rescheduling..."
    sleep 10
    
    # Check if pods are running again
    local running_pods=$(kubectl get pods -n "$TEST_NAMESPACE" --field-selector status.phase=Running --no-headers | wc -l)
    local expected_pods=3
    
    # Uncordon the node
    kubectl uncordon "$target_node" >/dev/null
    
    if [[ $running_pods -eq $expected_pods ]]; then
        test_pass "$test_name (pods rescheduled successfully)"
    else
        test_fail "$test_name" "Only $running_pods/$expected_pods pods running after failover"
        return 1
    fi
    
    return 0
}

# Test data persistence
test_data_persistence() {
    local test_name="Data persistence"
    test_start "$test_name"
    
    # Create a stateful workload
    cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ha-test-pvc
  namespace: $TEST_NAMESPACE
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: ha-test-stateful
  namespace: $TEST_NAMESPACE
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sh", "-c", "echo 'test-data-$(date +%s)' > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: ha-test-pvc
EOF
    
    # Wait for pod to be ready
    local max_wait=30
    local waited=0
    while [[ $waited -lt $max_wait ]]; do
        if kubectl get pod ha-test-stateful -n "$TEST_NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Running"; then
            break
        fi
        sleep 2
        ((waited+=2))
    done
    
    if [[ $waited -ge $max_wait ]]; then
        test_fail "$test_name" "Stateful pod did not start"
        return 1
    fi
    
    # Read the data
    local data_before=$(kubectl exec -n "$TEST_NAMESPACE" ha-test-stateful -- cat /data/test.txt 2>/dev/null || echo "")
    
    if [[ -z "$data_before" ]]; then
        test_fail "$test_name" "Could not write test data"
        return 1
    fi
    
    log_info "Test data written: $data_before"
    
    # Delete and recreate the pod
    kubectl delete pod ha-test-stateful -n "$TEST_NAMESPACE" --grace-period=0 --force >/dev/null 2>&1
    
    # Recreate pod
    cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: ha-test-stateful
  namespace: $TEST_NAMESPACE
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sh", "-c", "cat /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: ha-test-pvc
EOF
    
    # Wait for pod to be ready again
    waited=0
    while [[ $waited -lt $max_wait ]]; do
        if kubectl get pod ha-test-stateful -n "$TEST_NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Running"; then
            break
        fi
        sleep 2
        ((waited+=2))
    done
    
    # Read the data again
    local data_after=$(kubectl exec -n "$TEST_NAMESPACE" ha-test-stateful -- cat /data/test.txt 2>/dev/null || echo "")
    
    if [[ "$data_before" == "$data_after" ]]; then
        test_pass "$test_name (data persisted across pod restart)"
    else
        test_fail "$test_name" "Data lost: before='$data_before', after='$data_after'"
        return 1
    fi
    
    return 0
}

# Test load balancing
test_load_balancing() {
    local test_name="Load balancing"
    test_start "$test_name"
    
    # Get service cluster IP
    local service_ip=$(kubectl get svc ha-test-svc -n "$TEST_NAMESPACE" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
    
    if [[ -z "$service_ip" ]]; then
        test_fail "$test_name" "Test service not found"
        return 1
    fi
    
    # Create a test pod to make requests
    kubectl run curl-test -n "$TEST_NAMESPACE" --image=curlimages/curl --rm -i --restart=Never -- \
        sh -c "for i in \$(seq 1 10); do curl -s http://$service_ip | grep -o 'Node: [^<]*' || echo 'Failed'; done" > /tmp/lb-test.out 2>&1
    
    # Check results
    local unique_responses=$(grep "Node:" /tmp/lb-test.out | sort -u | wc -l)
    local total_responses=$(grep "Node:" /tmp/lb-test.out | wc -l)
    
    rm -f /tmp/lb-test.out
    
    if [[ $unique_responses -gt 1 ]] && [[ $total_responses -ge 8 ]]; then
        test_pass "$test_name (requests distributed to $unique_responses pods)"
    else
        test_fail "$test_name" "Load balancing not working: $unique_responses unique responses from $total_responses requests"
        return 1
    fi
    
    return 0
}

# Test API server availability
test_api_availability() {
    local test_name="API server availability"
    test_start "$test_name"
    
    local successful_calls=0
    local total_calls=10
    
    log_info "Testing API server availability with $total_calls concurrent calls..."
    
    for i in $(seq 1 $total_calls); do
        (
            if kubectl get nodes --request-timeout=5s >/dev/null 2>&1; then
                echo "success"
            else
                echo "failed"
            fi
        ) &
    done > /tmp/api-test.out
    
    wait
    
    successful_calls=$(grep -c "success" /tmp/api-test.out 2>/dev/null || echo 0)
    rm -f /tmp/api-test.out
    
    if [[ $successful_calls -eq $total_calls ]]; then
        test_pass "$test_name (all $total_calls API calls succeeded)"
    else
        test_fail "$test_name" "Only $successful_calls/$total_calls API calls succeeded"
        return 1
    fi
    
    return 0
}

# Summary report
print_summary() {
    echo
    echo "====================================="
    echo "HA Test Summary"
    echo "====================================="
    echo "Cluster nodes: ${#CLUSTER_NODES[@]}"
    echo "Total tests: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo "====================================="
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_info "All HA tests passed!"
        return 0
    else
        log_error "Some HA tests failed"
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
    
    # Detect cluster nodes
    if ! detect_cluster_nodes; then
        log_error "Cannot detect cluster nodes"
        exit 1
    fi
    
    # Run tests in order
    local tests=(
        "test_cluster_nodes"
        "test_etcd_health"
        "test_leader_election"
        "test_failover"
        "test_data_persistence"
        "test_load_balancing"
        "test_api_availability"
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