# Agent Scratchpad

## Current Context
- Task: Research best practices for declarative NixOS VMs on MacOS
- Goal: Compile findings in RESEARCH.md to inform orchard VM implementation
- Project: K3s HA cluster expansion with VM on Mac Studio (orchard) and Proxmox (coral)

## Existing Infrastructure
- microvm.nix already in flake inputs
- reef host has microvm configuration (hosts/reef/microvm.nix)
- Base k3s VM module exists (hosts/base-k3s-vm/)
- nixos-generators in flake inputs
- Target: Lima-based VM on Mac Studio (ARM64)

## Tasks

### Research Phase
- [x] Research Lima + NixOS integration approaches
- [x] Research nixos-generators for VM images
- [x] Research microvm.nix capabilities on Darwin
- [x] Research UTM as alternative to Lima
- [x] Research declarative VM management patterns
- [x] Compile findings in RESEARCH.md

### Implementation Phase (after research)
- [x] Choose VM approach for Mac Studio - DECISION: Native NixOS VM with virtualisation.host.pkgs
- [x] Create orchard host configuration
- [x] Add orchard to flake.nix
- [ ] Test VM build on Mac Studio
- [ ] Create VM provisioning/startup scripts
- [ ] Configure k3s on orchard
- [ ] Test k3s cluster join with reef

## Notes
- Orchard should be ARM64 (aarch64-darwin host, aarch64-linux guest)
- Need static IP 10.10.11.100
- Must join existing k3s cluster on reef
- Should use base-k3s-vm configuration
