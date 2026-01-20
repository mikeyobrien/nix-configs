# Proxmox VM Configuration

This directory contains Proxmox-related configurations for the k3s cluster VMs.

## Files

- `coral-template.conf` - VM template configuration for coral node

## Network Configuration

The k3s cluster uses a dedicated network on Proxmox:
- Network: 10.10.20.0/24
- Bridge: vmbr1
- Gateway: 10.10.20.1

### IP Assignments
- 10.10.20.11 - orchard (Mac Studio Lima VM - external)
- 10.10.20.12 - coral (Proxmox VM)
- 10.10.20.13 - reef (Proxmox host k3s node)

## Creating the Template

1. Download NixOS ISO:
   ```bash
   cd /var/lib/vz/template/iso/
   wget https://releases.nixos.org/nixos/24.05/nixos-24.05.{version}/nixos-minimal-24.05.{version}-x86_64-linux.iso
   ```

2. Create template VM:
   ```bash
   # Run on Proxmox host
   qm create 9000 \
     --name nixos-k3s-template \
     --memory 8192 \
     --cores 4 \
     --net0 virtio,bridge=vmbr1 \
     --scsi0 local-lvm:100
   ```

3. Install NixOS with minimal configuration

4. Install cloud-init support:
   ```nix
   # In configuration.nix
   services.cloud-init.enable = true;
   ```

5. Convert to template:
   ```bash
   qm template 9000
   ```

## Provisioning VMs

Use the provision script:
```bash
# Dry run to see what would happen
./scripts/provision-coral-vm.sh --dry-run

# Create and start VM
./scripts/provision-coral-vm.sh

# Recreate from scratch
./scripts/provision-coral-vm.sh --destroy-existing
```

## Manual VM Creation

If not using the template:
```bash
# Create VM
qm create 9002 \
  --name coral \
  --memory 8192 \
  --cores 4 \
  --net0 virtio,bridge=vmbr1 \
  --scsi0 local-lvm:100 \
  --cdrom local:iso/nixos-24.05-minimal.iso

# Configure network
qm set 9002 --ipconfig0 ip=10.10.20.12/24,gw=10.10.20.1

# Start VM
qm start 9002
```