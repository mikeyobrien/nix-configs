# K3s HA Cluster Implementation Plan (TDD Approach)

## Overview

This plan implements the k3s cluster expansion using Test-Driven Development principles. Each step includes tests that verify functionality before moving to the next step.

## Core Principles

1. **Red-Green-Refactor**: Write failing tests first, make them pass, then optimize
2. **Small Steps**: Each step is independently testable
3. **No Manual Testing**: Everything automated with scripts
4. **Fail Fast**: Tests catch issues immediately

## Test Infrastructure Setup

Before implementing features, we need testing capabilities:
- Nix evaluation tests
- VM provisioning tests  
- K3s cluster health tests
- Network connectivity tests

## Implementation Phases

### Phase 1: Foundation & Testing Framework (Steps 1-5)
1. Create test framework and directory structure
2. Create Python CLI testing tool
3. Implement base VM module with tests
4. Add configuration validation tests
5. Create test helpers for Nix modules

### Phase 2: Configuration Development (Steps 6-9)
6. Add k3s configuration with unit tests
7. Implement secret management with tests
8. Create host-specific configs with tests
9. Add flake integration tests

### Phase 3: VM Provisioning (Steps 10-13)
10. Develop Lima VM provisioning with tests
11. Create Proxmox VM automation with tests
12. Add VM validation scripts
13. Implement health check suite

### Phase 4: Integration & Deployment (Steps 14-17)
14. Create cluster formation tests
15. Add monitoring and observability
16. Implement rollback procedures
17. Final integration testing

## Detailed Implementation Prompts

### Step 1: Create Test Framework

```text
Set up a test framework for Nix configurations in a k3s cluster expansion project:

1. Create directory structure:
   - tests/
   - tests/unit/
   - tests/integration/
   - tests/helpers/

2. Create tests/run-all.sh that:
   - Runs all test suites
   - Reports results
   - Exits with failure if any test fails

3. Add a simple test example that verifies the test framework works

Make tests executable and follow bash best practices.
```

### Step 2: Create Python CLI Testing Tool

```text
Create a simple Python CLI tool for sanity testing the k3s cluster:

1. Create tests/sanity.py with:
   - Uses only Python standard library (no external dependencies)
   - Colorized output using ANSI codes
   - Clear pass/fail indicators

2. Implement these test functions:
   - check_nix_eval(config_path): Evaluates a Nix configuration
   - check_host_connectivity(hostname, port): Tests TCP connectivity
   - check_k3s_api(host, port): Validates k3s API response
   - check_ssh_access(host): Verifies SSH connectivity

3. Add a main() function that:
   - Accepts command-line arguments for which tests to run
   - Shows progress with checkmarks/crosses
   - Returns exit code 0 for success, 1 for any failure

4. Make it executable with #!/usr/bin/env python3

Keep it under 200 lines, simple and focused on sanity checks.
```

### Step 3: Base VM Module with Tests

```text
Create the base k3s VM module using TDD approach:

1. First, create tests/unit/test-base-vm.sh that tests:
   - Module can be evaluated
   - Required options are present
   - SSH is enabled
   - Basic packages are included

2. Create hosts/base-k3s-vm/ directory structure

3. Implement hosts/base-k3s-vm/configuration.nix with:
   - Basic NixOS module structure
   - SSH service enabled
   - Essential packages (vim, git, htop)
   - Make tests pass

4. Create hosts/base-k3s-vm/home.nix as minimal module

Run tests and ensure they pass before proceeding.
```

### Step 4: Configuration Validation Tests

```text
Add configuration validation tests for the base VM:

1. Create tests/unit/test-networking.sh that verifies:
   - Network configuration structure is valid
   - Firewall rules are properly formatted
   - Required ports will be opened

2. Update hosts/base-k3s-vm/configuration.nix to add:
   - Basic networking setup (DHCP as default)
   - Firewall with SSH (port 22) allowed
   - Network validation helper

3. Create tests/unit/test-packages.sh that checks:
   - Required packages are in the list
   - No conflicting packages
   - Package names are valid

Ensure all tests pass.
```

### Step 5: Test Helpers for Nix

```text
Create comprehensive test helpers for Nix module testing:

1. Create tests/helpers/eval-config.nix that:
   - Provides a minimal NixOS configuration for testing
   - Allows injecting test modules
   - Returns evaluatable configuration

2. Create tests/helpers/assertions.sh with functions:
   - assert_nix_eval() - checks if Nix expression evaluates
   - assert_option_set() - verifies option is set
   - assert_service_enabled() - checks service configuration
   - assert_package_installed() - verifies package in environment

3. Update existing tests to use these helpers

4. Add documentation for how to write new tests
```

### Step 6: K3s Configuration with Tests

```text
Add k3s configuration to base VM using TDD:

1. Create tests/unit/test-k3s.sh that tests:
   - K3s service is configured correctly
   - Server role is set
   - Token file path is configured
   - Required ports are open in firewall
   - Kubectl is in system packages

2. Update hosts/base-k3s-vm/configuration.nix to add:
   - services.k3s configuration
   - role = "server"
   - clusterInit = false
   - serverAddr = "https://10.10.11.39:6443"
   - Firewall ports: 6443, 2379-2380, 10250, etc.
   - kubectl to packages

3. Create tests/unit/test-k3s-networking.sh for:
   - Verifying all k3s ports are allowed
   - Network connectivity requirements

Make all tests pass.
```

### Step 7: Secret Management Tests

```text
Implement secret management with agenix, test-first:

1. Create tests/unit/test-secrets.sh that verifies:
   - Agenix secrets are properly referenced
   - K3s token secret is configured
   - Secret file paths are correct
   - Hosts have access to required secrets

2. Create placeholder host keys for testing:
   - tests/fixtures/studio-k3s-host-key.pub
   - tests/fixtures/proxmox-k3s-host-key.pub

3. Update secrets/secrets.nix to add:
   - studio-k3s host entry
   - proxmox-k3s host entry
   - Both hosts in k3s_secret.publicKeys

4. Update base VM configuration to reference k3s token

Tests should pass with mock keys.
```

### Step 8: Host-Specific Configuration Tests

```text
Create host-specific configurations with tests:

1. Create tests/unit/test-orchard.sh that tests:
   - Correct hostname is set (orchard)
   - Static IP configuration (10.10.11.100)
   - ARM64 architecture specifics
   - Imports base configuration

2. Implement hosts/orchard/configuration.nix:
   - Import base-k3s-vm
   - Set hostname and network config
   - Add any Mac-specific settings

3. Create tests/unit/test-coral.sh for:
   - Correct hostname (coral)
   - Static IP (10.10.11.101)
   - x86_64 architecture
   - Boot loader configuration

4. Implement hosts/coral/configuration.nix

Verify both configurations evaluate correctly.
```

### Step 9: Flake Integration Tests

```text
Add flake integration with comprehensive tests:

1. Create tests/integration/test-flake.sh that:
   - Verifies flake evaluates
   - Checks all hosts are defined
   - Validates orchard uses aarch64-linux
   - Validates coral uses x86_64-linux
   - Ensures no evaluation errors

2. Update flake.nix to add:
   - orchard to nixosConfigurations
   - coral to nixosConfigurations
   - Both using mkSystem helper

3. Create tests/integration/test-build.sh that:
   - Attempts to build configurations
   - Checks for common issues
   - Validates output paths

All configurations should build successfully.
```

### Step 10: Lima VM Provisioning Tests

```text
Develop Lima VM provisioning with tests:

1. Create tests/integration/test-lima.sh that:
   - Validates Lima YAML syntax
   - Checks resource allocations
   - Verifies network configuration
   - Tests without actually creating VM

2. Create lima/orchard.yaml with:
   - NixOS image specification
   - 4 CPUs, 8GB RAM, 50GB disk
   - Network settings for static IP
   - SSH configuration

3. Create scripts/provision-orchard-vm.sh that:
   - Validates Lima is installed
   - Checks for existing VMs
   - Creates VM with error handling
   - Includes rollback on failure

4. Add dry-run mode for testing
```

### Step 11: Proxmox Automation Tests

```text
Create Proxmox VM automation with testing:

1. Create tests/integration/test-proxmox.sh that:
   - Tests SSH connectivity to Proxmox
   - Validates VM creation commands
   - Checks resource availability
   - Uses mock mode for safety

2. Create scripts/provision-coral-vm.sh with:
   - SSH connection validation
   - VM existence checking
   - Resource allocation (4CPU, 8GB RAM)
   - Network bridge configuration
   - Comprehensive error handling

3. Add --dry-run flag that:
   - Shows commands without executing
   - Validates parameters
   - Checks prerequisites

4. Create VM template for faster provisioning
```

### Step 12: VM Validation Scripts

```text
Create comprehensive VM validation:

1. Create tests/validation/validate-vm.sh that:
   - Checks VM is running
   - Validates network connectivity
   - Verifies SSH access
   - Tests DNS resolution
   - Checks disk space

2. Create tests/validation/validate-nix.sh for:
   - Nix installation verification
   - Flake support enabled
   - Configuration can be rebuilt
   - No evaluation errors

3. Create scripts/wait-for-vm.sh that:
   - Polls for VM availability
   - Implements timeout
   - Shows progress
   - Returns proper exit codes

All scripts should be idempotent.
```

### Step 13: Health Check Suite

```text
Implement comprehensive health checking:

1. Create tests/health/check-node.sh that:
   - Verifies k3s service is running
   - Checks API server accessibility
   - Validates etcd health
   - Tests kubectl functionality

2. Create tests/health/check-cluster.sh for:
   - All nodes are Ready
   - etcd has correct member count
   - API is highly available
   - Workloads are running

3. Create monitoring/health-dashboard.sh that:
   - Shows cluster status
   - Displays node health
   - Reports resource usage
   - Uses color coding

4. Add continuous health monitoring option
```

### Step 14: Cluster Formation Tests

```text
Test cluster formation process:

1. Create tests/integration/test-cluster-join.sh that:
   - Simulates node joining
   - Validates token usage
   - Checks etcd membership
   - Verifies HA setup

2. Create scripts/join-cluster.sh that:
   - Validates prerequisites
   - Checks network connectivity to reef
   - Joins cluster with retry logic
   - Verifies successful join

3. Create tests/integration/test-ha.sh for:
   - Leader election works
   - Failover scenarios
   - etcd quorum maintained
   - API remains accessible

Document expected behavior.
```

### Step 15: Monitoring Setup

```text
Add monitoring with tests:

1. Create tests/monitoring/test-exporters.sh that:
   - Node exporter is configured
   - Metrics are accessible
   - Firewall allows scraping
   - Prometheus can connect

2. Update base configuration to add:
   - Prometheus node exporter
   - Port 9100 in firewall
   - Basic metric collection

3. Create monitoring/test-metrics.sh that:
   - Queries metrics endpoint
   - Validates key metrics present
   - Checks metric values reasonable

4. Add alerts for critical issues
```

### Step 16: Rollback Procedures

```text
Implement safe rollback capabilities:

1. Create tests/rollback/test-rollback.sh that:
   - Configuration can be reverted
   - Cluster remains stable
   - No data loss occurs
   - Validates rollback procedures

2. Create scripts/rollback-vm.sh that:
   - Saves current configuration
   - Reverts to previous generation
   - Maintains cluster connectivity
   - Includes safety checks

3. Create backup/restore procedures:
   - Configuration backups
   - etcd snapshots
   - Restore testing
   - Verification steps

4. Document rollback scenarios
```

### Step 17: Final Integration Tests

```text
Complete integration testing suite:

1. Create tests/e2e/full-deployment.sh that:
   - Creates both VMs from scratch
   - Deploys configurations
   - Forms 3-node cluster
   - Validates HA functionality
   - Tests failure scenarios

2. Create tests/e2e/workload-test.sh for:
   - Deploying test workload
   - Verifying scheduling
   - Testing node drain
   - Validating data persistence

3. Create performance benchmarks:
   - API response times
   - etcd latency
   - Network throughput
   - Resource utilization

4. Generate test report with all results
```

## Test Execution Strategy

### Continuous Testing
- Run unit tests on every change
- Integration tests before deployment
- Health checks run continuously
- Performance tests weekly

### Test Categories
1. **Unit Tests**: Fast, isolated, frequent
2. **Integration Tests**: Component interaction
3. **E2E Tests**: Full system validation
4. **Performance Tests**: Baseline tracking

### Failure Handling
- Tests must be deterministic
- Clear error messages
- Automated rollback triggers
- Incident documentation

## Success Criteria

All tests must pass before considering implementation complete:
- 100% unit test coverage
- Integration tests succeed
- E2E deployment works
- Performance meets baseline
- Documentation updated