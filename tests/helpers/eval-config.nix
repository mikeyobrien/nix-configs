# ABOUTME: Minimal NixOS configuration builder for testing Nix modules
# ABOUTME: Provides a base configuration that can be extended for unit tests

{ nixpkgs ? (builtins.getFlake (toString ../..)).inputs.nixpkgs
, system ? "x86_64-linux"
, modules ? []
}:

let
  # Base configuration required for any NixOS system
  baseModule = { config, lib, pkgs, ... }: {
    # Minimal boot configuration
    boot.loader.grub.enable = false;
    
    # Minimal filesystem
    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };
    
    # Default hostname
    networking.hostName = lib.mkDefault "test-system";
    
    # Disable documentation to speed up evaluation
    documentation.enable = lib.mkForce false;
    
    # Minimal nixpkgs configuration
    nixpkgs.config = {};
    nixpkgs.hostPlatform = system;
    
    # Default state version
    system.stateVersion = lib.mkDefault "24.05";
  };
in
nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [ baseModule ] ++ modules;
}