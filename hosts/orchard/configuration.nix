# ABOUTME: Orchard - K3s control plane VM running on Mac Studio (aarch64-darwin host)
# ABOUTME: Uses native NixOS VM with virtualisation.host.pkgs for declarative VM on macOS

{ config, pkgs, lib, ... }:

{
  imports = [
    ../base-k3s-vm/configuration.nix
  ];

  # Boot configuration for VM
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  # Root filesystem
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  # Hostname and networking
  networking = {
    hostName = "orchard";
    useDHCP = false;
    
    # Static IP configuration for k3s cluster
    interfaces.eth0 = {
      ipv4.addresses = [{
        address = "10.10.11.100";
        prefixLength = 24;
      }];
    };
    
    defaultGateway = "10.10.11.1";
    nameservers = [ "10.10.11.1" "1.1.1.1" ];
    
    # K3s required ports
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22    # SSH
        6443  # Kubernetes API
        10250 # Kubelet
        2379  # etcd client
        2380  # etcd peer
      ];
      allowedUDPPorts = [
        8472  # Flannel VXLAN
      ];
    };
  };

  # User configuration
  users.users.mobrienv = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      # Add SSH public key here
    ];
  };

  # VM-specific settings for running on Darwin host
  virtualisation.vmVariant = {
    virtualisation = {
      # Use host packages from aarch64-darwin
      # This will be set in flake.nix: host.pkgs = nixpkgs.legacyPackages.aarch64-darwin
      
      # VM resources
      memorySize = 8192;  # 8GB RAM
      cores = 4;
      
      # Disk size
      diskSize = 100 * 1024;  # 100GB
      
      # Use serial console instead of graphical window
      graphics = false;

      # Network configuration
      forwardPorts = [
        { from = "host"; host.port = 6443; guest.port = 6443; }  # K8s API
        { from = "host"; host.port = 2222; guest.port = 22; }    # SSH
      ];
    };
  };

  system.stateVersion = "24.05";
}
