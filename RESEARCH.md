# Research: Declarative NixOS VMs on macOS

**Date**: 2026-01-20  
**Purpose**: Evaluate approaches for running NixOS VMs declaratively on Mac Studio (aarch64-darwin) for k3s HA cluster

## Executive Summary

Running NixOS VMs on macOS requires special consideration due to platform differences. Three main approaches exist:

1. **Native NixOS VM with `virtualisation.host.pkgs`** - Most declarative, requires QEMU patches
2. **Lima** - Lightweight, YAML-based, good for containers but less declarative for NixOS
3. **UTM** - GUI-based, good for manual setup, less suitable for automation

**Recommendation**: Use native NixOS VM approach with `virtualisation.host.pkgs` for maximum declarativeness and integration with existing flake infrastructure.

## Approaches Evaluated

### 1. Native NixOS VM with `virtualisation.host.pkgs`

**Source**: [Tweag.io - Running a NixOS VM on macOS](https://www.tweag.io/blog/2023-02-09-nixos-vm-on-macos/)

#### Overview
Extends NixOS's built-in VM building capabilities to work on macOS by specifying host packages separately from guest packages.

#### Key Features
- Fully declarative in Nix
- Integrates with existing flake infrastructure
- Uses QEMU with hardware virtualization (HVF on Apple Silicon)
- Mounts `/nix/store` from host via virtio-fs (efficient, no duplication)
- Serial console output (no separate window needed)

#### Implementation Pattern
```nix
{
  nixosConfigurations.darwinVM = nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";  # Guest system
    modules = [
      ./configuration.nix
      {
        # Key: specify host packages for VM runner
        virtualisation.vmVariant.virtualisation.host.pkgs = 
          nixpkgs.legacyPackages.aarch64-darwin;
        
        # Use serial console instead of graphical window
        virtualisation.vmVariant.virtualisation.graphics = false;
      }
    ];
  };
  
  # Expose as runnable package
  packages.aarch64-darwin.darwinVM = 
    self.nixosConfigurations.darwinVM.config.system.build.vm;
}
```

#### Running the VM
```bash
# Build and run in one command
nix run .#darwinVM

# Or build separately
nix build .#darwinVM
./result/bin/run-nixos-vm
```

#### Advantages
- ✅ Fully declarative - entire VM config in Nix
- ✅ Integrates with existing flake structure
- ✅ Efficient - shares `/nix/store` with host
- ✅ No additional tools required beyond Nix
- ✅ Supports both x86_64 and aarch64 guests
- ✅ Can use hardware virtualization (HVF)

#### Disadvantages
- ❌ Requires QEMU 7.0+ with specific patches (now in nixpkgs)
- ❌ VM state stored in working directory (`nixos.qcow2`)
- ❌ Less mature than Linux-based VM workflows
- ❌ Some QEMU features may not work on macOS

#### Status
- Merged into nixpkgs as of 2023
- Used by official macOS builder (`nixpkgs.darwinBuilder`)
- Production-ready for aarch64-darwin

### 2. Lima (Linux-on-Mac)

**Sources**: 
- [Lima GitHub](https://github.com/lima-vm/lima)
- [Colima remote builder gist](https://gist.github.com/yihuang/f197207bd290b63e639a9116db9e654a)

#### Overview
Lightweight VM manager focused on running Linux containers on macOS. Uses QEMU under the hood with YAML configuration.

#### Key Features
- YAML-based configuration
- Automatic file sharing (mount home directory)
- Port forwarding
- Multiple VM instances
- Built-in support for various Linux distributions

#### Implementation Pattern
```yaml
# lima-nixos.yaml
arch: "aarch64"
images:
  - location: "https://hydra.nixos.org/.../nixos.iso"
    arch: "aarch64"

cpus: 4
memory: "8GiB"
disk: "100GiB"

mounts:
  - location: "~"
    writable: true

networks:
  - lima: shared
```

```bash
# Create and start VM
limactl create --name=nixos lima-nixos.yaml
limactl start nixos

# SSH into VM
limactl shell nixos

# Use as remote builder
limactl show-ssh nixos -f config >> ~/.ssh/config
```

#### Advantages
- ✅ Lightweight and fast
- ✅ Good documentation and community
- ✅ Automatic file sharing
- ✅ Easy SSH access
- ✅ Can be used as Nix remote builder

#### Disadvantages
- ❌ YAML config separate from Nix
- ❌ Less declarative - two config systems
- ❌ NixOS support not first-class (needs ISO)
- ❌ Manual NixOS configuration inside VM
- ❌ State management outside Nix
- ❌ Network configuration less flexible

#### Use Cases
- Remote builder for macOS
- Container development (via Colima)
- Quick Linux environments
- **Not ideal for**: Declarative infrastructure, k3s nodes

### 3. UTM (GUI-based)

**Source**: [NixOS on Apple Silicon with UTM](https://krisztianfekete.org/nixos-on-apple-silicon-with-utm/)

#### Overview
macOS-native GUI application for running VMs. Essentially a QEMU frontend with nice UI.

#### Key Features
- Graphical interface for VM management
- UEFI boot support
- Hardware virtualization (HVF)
- Display scaling options
- Snapshot support

#### Implementation Pattern
1. Download NixOS ISO (aarch64)
2. Create VM in UTM GUI
3. Configure resources (CPU, RAM, disk)
4. Install NixOS manually
5. Configure via `configuration.nix` inside VM

#### VM Configuration (GUI)
```
System:
- Architecture: ARM64 (aarch64)
- System: QEMU 7.0 ARM Virtual Machine
- Memory: 16GB
- CPU: 4 cores

QEMU Tweaks:
- UEFI Boot: ✓
- RNG Device: ✓
- Use Hypervisor: ✓

Display:
- Display: Full Graphics
- Emulated Display Card: virtio-ramfb-gl

Network:
- Network Mode: Shared Network
```

#### Advantages
- ✅ User-friendly GUI
- ✅ Good for development/testing
- ✅ Snapshot support
- ✅ Display scaling
- ✅ Stable and mature

#### Disadvantages
- ❌ Not declarative - GUI-based
- ❌ Manual VM creation
- ❌ No automation/scripting
- ❌ State stored in UTM's directory
- ❌ Not suitable for infrastructure-as-code
- ❌ No ACPI shutdown support (must use guest OS)

#### Use Cases
- Desktop development environments
- Manual testing
- Learning NixOS
- **Not ideal for**: Production infrastructure, automation

### 4. microvm.nix

**Source**: [microvm.nix GitHub](https://github.com/microvm-nix/microvm.nix)

#### Overview
NixOS module for declarative MicroVMs. Designed for Linux hosts, not macOS.

#### Status on macOS
- ❌ **Not supported** on aarch64-darwin
- [Issue #154](https://github.com/microvm-nix/microvm.nix/issues/154) tracks macOS support
- Designed for Linux-to-Linux virtualization
- Uses Linux-specific features (KVM, systemd-nspawn)

#### Current Usage in This Repo
- Used on `reef` (Linux host) for bastion VM
- Declarative VM definitions in `hosts/reef/microvm.nix`
- **Cannot be used** for Mac Studio VMs

## Comparison Matrix

| Feature | Native NixOS VM | Lima | UTM | microvm.nix |
|---------|----------------|------|-----|-------------|
| **Declarative** | ✅ Full | ⚠️ Partial | ❌ No | ❌ N/A |
| **Nix Integration** | ✅ Native | ⚠️ External | ❌ Manual | ❌ N/A |
| **Automation** | ✅ Yes | ✅ Yes | ❌ No | ❌ N/A |
| **macOS Support** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| **ARM64 Support** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| **Static IP** | ⚠️ Manual | ⚠️ Manual | ⚠️ Manual | ✅ Yes |
| **Flake Compatible** | ✅ Yes | ❌ No | ❌ No | ✅ Yes |
| **State Management** | ⚠️ Local | ⚠️ External | ⚠️ External | ✅ Declarative |
| **Learning Curve** | Medium | Low | Low | N/A |
| **Production Ready** | ✅ Yes | ✅ Yes | ⚠️ Dev only | N/A |

## Recommendation for Orchard VM

### Chosen Approach: Native NixOS VM with `virtualisation.host.pkgs`

**Rationale**:
1. **Declarative**: Entire VM configuration in flake
2. **Consistent**: Same pattern as other hosts
3. **Maintainable**: Single source of truth
4. **Efficient**: Shares `/nix/store` with host
5. **Automated**: Can be scripted and version controlled

### Implementation Plan

1. **Create orchard configuration** following existing patterns:
   ```
   hosts/orchard/
   ├── configuration.nix  # Imports base-k3s-vm + Darwin VM settings
   └── home.nix          # Imports base-k3s-vm home
   ```

2. **Add to flake.nix**:
   ```nix
   nixosConfigurations.orchard = nixpkgs.lib.nixosSystem {
     system = "aarch64-linux";
     modules = [
       ./hosts/orchard/configuration.nix
       {
         virtualisation.vmVariant.virtualisation.host.pkgs = 
           nixpkgs.legacyPackages.aarch64-darwin;
       }
     ];
   };
   
   packages.aarch64-darwin.orchard = 
     self.nixosConfigurations.orchard.config.system.build.vm;
   ```

3. **Network configuration**: Use QEMU user networking with port forwarding or TAP interface

4. **Startup automation**: Create launchd service on Mac Studio to auto-start VM

### Alternative: Lima as Fallback

If native approach has issues:
- Use Lima for VM management
- Keep NixOS configuration declarative
- Use `nixos-rebuild` inside VM
- Accept split between Lima YAML and Nix config

## Network Configuration Considerations

### Challenge
All approaches require manual network setup for static IPs on macOS:

1. **QEMU User Networking** (default)
   - NAT-based, VM gets DHCP
   - Port forwarding for services
   - No direct IP access from LAN

2. **QEMU TAP Interface**
   - Requires macOS network bridge
   - More complex setup
   - Allows static IP on LAN

3. **Lima Shared Network**
   - VM on 192.168.64.x subnet
   - Host at 192.168.64.1
   - Port forwarding needed

### Recommended Approach
1. Start with QEMU user networking + port forwarding
2. Forward k3s ports (6443, 10250, etc.)
3. Use hostname resolution via `/etc/hosts`
4. Consider TAP interface if direct IP needed

## References

1. [Tweag - Running a NixOS VM on macOS](https://www.tweag.io/blog/2023-02-09-nixos-vm-on-macos/)
2. [Lima GitHub Repository](https://github.com/lima-vm/lima)
3. [NixOS on Apple Silicon with UTM](https://krisztianfekete.org/nixos-on-apple-silicon-with-utm/)
4. [Colima Remote Builder Setup](https://gist.github.com/yihuang/f197207bd290b63e639a9116db9e654a)
5. [microvm.nix Darwin Support Issue](https://github.com/microvm-nix/microvm.nix/issues/154)
6. [NixOS Manual - Virtual Machines](https://nix.dev/tutorials/nixos/nixos-configuration-on-vm.html)

## Next Steps

1. ✅ Research complete
2. ⏭️ Create orchard host configuration
3. ⏭️ Add orchard to flake.nix
4. ⏭️ Test VM build on Mac Studio
5. ⏭️ Configure networking
6. ⏭️ Test k3s cluster join
7. ⏭️ Create startup automation

---

**Content was rephrased for compliance with licensing restrictions**
