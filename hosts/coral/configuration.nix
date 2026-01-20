# ABOUTME: NixOS configuration for coral - k3s control plane node on Proxmox VM
# ABOUTME: x86_64 VM that joins the k3s HA cluster as a control plane node

{ config, pkgs, lib, ... }:

{
  imports = [
    ../base-k3s-vm/configuration.nix
  ];

  # System identification
  networking.hostName = "coral";
  
  # Enable k3s service for this host
  services.k3s = {
    enable = true;
    clusterInit = false;  # This node joins the existing cluster
    serverAddr = "https://10.10.11.39:6443";  # Reef's k3s API server
  };

  # Static network configuration
  networking = {
    useDHCP = false;
    
    # Static IP configuration for coral
    interfaces.eth0 = {
      useDHCP = false;
      ipv4.addresses = [{
        address = "10.10.11.101";
        prefixLength = 23;  # /23 subnet (10.10.10.0/23)
      }];
    };
    
    # Default gateway and DNS
    defaultGateway = {
      address = "10.10.10.1";
      interface = "eth0";
    };
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    
    # Override firewall configuration from base to ensure proper k3s ports
    firewall = {
      enable = true;
      # Inherit k3s ports from base configuration
      allowedTCPPorts = [
        22    # SSH
        6443  # Kubernetes API server
        10250 # Kubelet API
        2379  # etcd client requests
        2380  # etcd peer communication
      ];
      
      allowedTCPPortRanges = [
        { from = 30000; to = 32767; }  # NodePort range
      ];
      
      allowedUDPPorts = [
        8472  # Flannel VXLAN
      ];
    };
  };

  # x86_64-specific optimizations for Proxmox VM
  boot = {
    # Proxmox VM kernel parameters
    kernel.sysctl = {
      # Inherit base k3s kernel parameters and add x86_64-specific ones
      "kernel.sched_autogroup_enabled" = 0;  # Better for containerized workloads
      "vm.max_map_count" = 262144;  # Required for some k8s workloads
      "net.netfilter.nf_conntrack_max" = 131072;  # Increased connection tracking
    };
    
    # Enable KVM guest optimizations
    kernelModules = [ "kvm-intel" "virtio_balloon" "virtio_blk" "virtio_net" ];
  };

  # Proxmox VM specific configurations
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = lib.mkDefault true;
  
  # Hardware-specific optimizations for Proxmox
  hardware = {
    # Enable CPU microcode updates
    cpu.intel.updateMicrocode = lib.mkDefault true;
    # Enable firmware updates
    enableRedistributableFirmware = lib.mkDefault true;
  };
  
  # Timezone for Proxmox host location
  time.timeZone = "America/Los_Angeles";
  
  # System state version
  system.stateVersion = "24.05";

  # Additional packages for Proxmox VM environment
  environment.systemPackages = with pkgs; [
    # VM guest tools and utilities
    qemu-utils
    # Proxmox-specific tools
    pciutils
    usbutils
  ];

  # Optimize SSH for server environment
  services.openssh.settings = {
    # More restrictive for server environment
    X11Forwarding = false;
    PermitRootLogin = "no";
    PasswordAuthentication = false;
  };

  # Minimal documentation for server environment
  documentation = {
    enable = lib.mkDefault false;  # Save space and resources
    man.enable = true;  # Keep man pages for troubleshooting
  };

  # Automatic garbage collection for server environment
  nix.gc = {
    automatic = true;
    dates = lib.mkForce "daily";  # Override base weekly setting
    options = lib.mkForce "--delete-older-than 7d";  # More aggressive cleanup
  };

  # Power management for VM
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "ondemand";
  };
}