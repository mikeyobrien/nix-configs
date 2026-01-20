# ABOUTME: Home Manager configuration for coral - user environment for k3s control plane node
# ABOUTME: Server-focused user environment for Proxmox VM

{ config, pkgs, lib, ... }:

{
  # User account configuration
  home = {
    username = lib.mkDefault "mobrienv";
    homeDirectory = lib.mkDefault "/home/mobrienv";
    stateVersion = "24.05";
  };

  # Essential tools for server management
  home.packages = with pkgs; [
    # Kubernetes and container tools
    kubectl
    k9s
    
    # Essential utilities (minimal set for server)
    just
    
    # Network utilities
    dig
    nmap
    
    # System monitoring
    btop
  ];

  # Shell configuration
  programs = {
    # Fish shell with server-friendly prompt
    fish = {
      enable = true;
      shellAbbrs = {
        # Kubernetes shortcuts
        k = "kubectl";
        kgp = "kubectl get pods";
        kgs = "kubectl get services";
        kgn = "kubectl get nodes";
        
        # k3s specific
        k3s-status = "sudo systemctl status k3s";
        k3s-logs = "sudo journalctl -u k3s -f";
        
        # System shortcuts
        ll = "ls -la";
        la = "ls -la";
        
        # Server management
        services = "sudo systemctl list-units --type=service";
        logs = "sudo journalctl -f";
      };
    };

    # Minimal git configuration
    git = {
      enable = true;
      userName = lib.mkDefault "mobrienv";
      userEmail = lib.mkDefault "mobrienv@example.com";
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
      };
    };

    # Simple prompt for server environment
    starship = {
      enable = true;
      settings = {
        format = "$directory$kubernetes$git_branch$character";
        kubernetes = {
          disabled = false;
          format = "on [⛵ ($cluster)] ";
        };
        directory = {
          truncation_length = 2;
          format = "[$path]($style) ";
        };
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };
      };
    };
  };

  # Server environment variables
  home.sessionVariables = {
    EDITOR = "vim";
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    # Minimal PATH additions for server
  };

  # XDG directories
  xdg.enable = true;

  # Conservative package configuration for server
  nixpkgs.config.allowUnfree = false;  # Only FOSS packages for server
}