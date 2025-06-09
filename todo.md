# K3s HA Cluster Implementation TODO

## Status Tracking

This file tracks the implementation status of each step in the plan.

### Legend
- [ ] Not started
- [~] In progress
- [x] Completed
- [!] Blocked

## Phase 1: Foundation & Testing Framework

### Step 1: Create Test Framework
- [x] Create tests/ directory structure
- [x] Create tests/run-all.sh
- [x] Add simple test example

### Step 2: Create Python CLI Testing Tool
- [x] Create tests/sanity.py
- [x] Implement check_nix_eval()
- [x] Implement check_host_connectivity()
- [x] Implement check_k3s_api()
- [x] Implement check_ssh_access()
- [x] Add main() with CLI args

### Step 3: Base VM Module with Tests
- [x] Create tests/unit/test-base-vm.sh
- [x] Create hosts/base-k3s-vm/configuration.nix
- [x] Create hosts/base-k3s-vm/home.nix

### Step 4: Configuration Validation Tests
- [x] Create tests/unit/test-networking.sh
- [x] Update base configuration with networking
- [x] Create tests/unit/test-packages.sh

### Step 5: Test Helpers for Nix
- [ ] Create tests/helpers/eval-config.nix
- [ ] Create tests/helpers/assertions.sh
- [ ] Update existing tests to use helpers
- [ ] Add documentation

## Phase 2: Configuration Development

### Step 6: K3s Configuration with Tests
- [ ] Create tests/unit/test-k3s.sh
- [ ] Add k3s service to base configuration
- [ ] Add firewall rules for k3s
- [ ] Create tests/unit/test-k3s-networking.sh

### Step 7: Secret Management Tests
- [ ] Create tests/unit/test-secrets.sh
- [ ] Create placeholder host keys
- [ ] Update secrets/secrets.nix
- [ ] Update base VM to reference k3s token

### Step 8: Host-Specific Configuration Tests
- [ ] Create tests/unit/test-orchard.sh
- [ ] Implement hosts/orchard/configuration.nix
- [ ] Implement hosts/orchard/home.nix
- [ ] Create tests/unit/test-coral.sh
- [ ] Implement hosts/coral/configuration.nix
- [ ] Implement hosts/coral/home.nix

### Step 9: Flake Integration Tests
- [ ] Create tests/integration/test-flake.sh
- [ ] Update flake.nix with orchard
- [ ] Update flake.nix with coral
- [ ] Create tests/integration/test-build.sh

## Phase 3: VM Provisioning

### Step 10: Lima VM Provisioning Tests
- [ ] Create tests/integration/test-lima.sh
- [ ] Create lima/orchard.yaml
- [ ] Create scripts/provision-orchard-vm.sh
- [ ] Add dry-run mode

### Step 11: Proxmox Automation Tests
- [ ] Create tests/integration/test-proxmox.sh
- [ ] Create scripts/provision-coral-vm.sh
- [ ] Add dry-run flag
- [ ] Create VM template

### Step 12: VM Validation Scripts
- [ ] Create tests/validation/validate-vm.sh
- [ ] Create tests/validation/validate-nix.sh
- [ ] Create scripts/wait-for-vm.sh

### Step 13: Health Check Suite
- [ ] Create tests/health/check-node.sh
- [ ] Create tests/health/check-cluster.sh
- [ ] Create monitoring/health-dashboard.sh
- [ ] Add continuous monitoring option

## Phase 4: Integration & Deployment

### Step 14: Cluster Formation Tests
- [ ] Create tests/integration/test-cluster-join.sh
- [ ] Create scripts/join-cluster.sh
- [ ] Create tests/integration/test-ha.sh

### Step 15: Monitoring Setup
- [ ] Create tests/monitoring/test-exporters.sh
- [ ] Update base config with node exporter
- [ ] Create monitoring/test-metrics.sh
- [ ] Add critical alerts

### Step 16: Rollback Procedures
- [ ] Create tests/rollback/test-rollback.sh
- [ ] Create scripts/rollback-vm.sh
- [ ] Create backup/restore procedures
- [ ] Document rollback scenarios

### Step 17: Final Integration Tests
- [ ] Create tests/e2e/full-deployment.sh
- [ ] Create tests/e2e/workload-test.sh
- [ ] Create performance benchmarks
- [ ] Generate test report

## Notes

### Dependencies
- Lima must be installed on Mac Studio
- SSH access to Proxmox host at 10.10.10.10
- Existing k3s token in agenix secrets

### Risks
- Architecture differences between ARM64 and x86_64
- Network configuration complexity
- etcd cluster formation timing

### Next Steps
1. Start with Step 1 - Create test framework
2. Validate each phase before proceeding
3. Document any deviations from plan