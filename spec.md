# K3s High Availability Cluster Expansion Specification

## Project Overview

Expand the existing single-node k3s cluster on `reef` to a 3-node high-availability control plane cluster by adding NixOS VMs on Studio (Mac) and Proxmox hosts. This maintains the power-efficient architecture where high-performance workloads run on reef while control plane duties are distributed across always-on nodes.

## Architecture Summary

### Cluster Topology
- **3 Control Plane Nodes** (all running k3s server with embedded etcd for HA)
  - `reef` (10.10.11.39) - Existing NixOS physical server (Intel/NVIDIA, on-demand)
  - `orchard` (10.10.11.100) - New NixOS VM on Mac Studio (ARM64, always-on)
  - `coral` (10.10.11.101) - New NixOS VM on Proxmox (x86_64, always-on)

### Design Decisions
- Use embedded etcd (simpler than external etcd)
- Keep all existing workloads on reef initially
- No scheduling changes initially - migrate workloads gradually
- SSH-based access for VM management
- Shared base configuration for both VMs despite architecture differences

## Technical Specifications

### VM Resources
Both VMs will have:
- **CPU**: 4 cores
- **RAM**: 8-16GB
- **Disk**: 50-100GB
- **Network**: Static IP on 10.10.10.0/23 subnet

### Virtualization Platforms
- **Studio**: Lima (CLI-focused, NixOS support, lightweight)
- **Proxmox**: Standard KVM VM via Proxmox CLI

### K3s Configuration
- **Role**: Server (control plane)
- **Token**: Use existing token from reef (stored in k3s_secret.age)
- **Join Method**: Connect to reef's API at https://10.10.11.39:6443
- **etcd**: Embedded HA mode (automatic with 3 servers)

## Implementation Plan

### Phase 1: Base Configuration
1. Create shared base VM configuration at `hosts/base-k3s-vm/`
   - Minimal NixOS setup
   - K3s server configuration
   - Basic monitoring (node exporter)
   - SSH access
   - Network configuration template

### Phase 2: VM Deployment
1. **Proxmox VM Setup**
   - Create VM via Proxmox CLI commands (via SSH)
   - Install NixOS using ISO
   - Apply configuration from `hosts/coral/`
   
2. **Studio VM Setup**
   - Install Lima on Mac Studio
   - Create NixOS VM with Lima
   - Apply configuration from `hosts/orchard/`

### Phase 3: Cluster Formation
1. Start both VMs with k3s server configuration
2. Verify etcd cluster health (should show 3 members)
3. Test kubectl access from all nodes
4. Verify HA by stopping one node at a time

### Phase 4: Workload Migration (Future)
- Gradually move always-on services to orchard and coral
- Configure node selectors/taints as needed
- Implement power management for reef

## File Structure

```
hosts/
├── base-k3s-vm/
│   ├── configuration.nix    # Shared k3s and system config
│   └── home.nix             # Minimal home-manager config
├── orchard/
│   ├── configuration.nix    # Imports base + Studio-specific
│   └── home.nix            # Imports base home
├── coral/
│   ├── configuration.nix    # Imports base + Proxmox-specific
│   └── home.nix            # Imports base home
```

## Base VM Configuration Elements

### configuration.nix (shared)
- K3s server with clusterInit = false (joining existing cluster)
- Server URL pointing to reef
- Token from agenix secrets
- Basic firewall rules for k3s
- SSH daemon enabled
- Prometheus node exporter
- Standard packages (kubectl, htop, etc.)

### Host-specific overrides
- Hostname
- Static IP configuration
- Architecture-specific settings

## Security Considerations
- All nodes use the same k3s token (from agenix)
- SSH access restricted to authorized keys
- Firewall enabled with only required ports open
- Regular NixOS security updates

## Testing Plan
1. Verify individual node health
2. Test etcd cluster status
3. Validate workload scheduling
4. Test node failure scenarios
5. Verify cluster recovery

## Success Criteria
- 3-node etcd cluster with healthy quorum
- Kubectl works from any node
- Existing workloads continue running on reef
- Cluster survives single node failure
- Can schedule new workloads to any node

## Future Enhancements
- Implement node taints for reef (compute workloads only)
- Add node labels for workload placement
- Configure power management automation
- Set up monitoring dashboards
- Implement backup strategies for etcd