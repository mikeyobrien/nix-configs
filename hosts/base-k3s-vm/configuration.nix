# ABOUTME: Base configuration module for k3s VM nodes in the HA cluster
# ABOUTME: Provides common settings for all k3s control plane VMs

{ config, pkgs, lib, ... }:

{
  # Enable SSH for remote management
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Essential system packages
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    tmux
    curl
    wget
    tree
    jq
    dnsutils  # provides dig, nslookup, etc.
    netcat-gnu
    iotop
    ncdu
  ];

  # Time zone configuration
  time.timeZone = "America/Los_Angeles";

  # Enable Nix flakes and other experimental features
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-users = [ "@wheel" ];
    };
    
    # Garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Basic networking setup (will be overridden by specific hosts)
  networking = {
    useDHCP = lib.mkDefault true;
    
    # Firewall configuration
    firewall = {
      enable = true;
      # SSH is automatically opened when openssh.enable = true
      # Additional ports will be added for k3s in later steps
    };
  };

  # System documentation
  documentation = {
    enable = true;
    man.enable = true;
  };

  # Enable systemd-resolved for DNS
  services.resolved = {
    enable = true;
    dnssec = "false";  # Set to false for compatibility
  };

  # Basic system hardening
  security = {
    sudo = {
      wheelNeedsPassword = true;
      execWheelOnly = true;
    };
  };

  # Kernel parameters for better k3s performance
  boot.kernel.sysctl = {
    # Increase max connections
    "net.core.somaxconn" = 32768;
    # Increase network buffer sizes
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    # Enable IP forwarding (required for k3s)
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    # Disable swap (recommended for k3s)
    "vm.swappiness" = 0;
  };

  # System state version (will be overridden by specific hosts)
  system.stateVersion = lib.mkDefault "24.05";
}