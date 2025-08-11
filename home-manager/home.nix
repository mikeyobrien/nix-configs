# ABOUTME: Minimal base home-manager configuration
# ABOUTME: Provides only essential packages and shell - hosts add what they need

{
  config,
  pkgs,
  lib,
  inputs,
  outputs,
  user,
  ...
}: 

{
  imports = [
    # Import all available modules
    outputs.homeManagerModules.core
    outputs.homeManagerModules.shells
    outputs.homeManagerModules.terminal
    outputs.homeManagerModules.editors
    outputs.homeManagerModules.development
    outputs.homeManagerModules.llm
    # Note: profiles are not imported here - hosts choose which profiles to use
  ];

  nixpkgs.overlays = [
      outputs.overlays.modifications
      outputs.overlays.additions
      outputs.overlays.unstable-packages
  ];

  # Minimal defaults - just essentials and a shell
  modules.core.essential.enable = lib.mkDefault true;
  modules.shells.fish.enable = lib.mkDefault true;
  modules.shells.prompts.enable = lib.mkDefault true;

  # System management - always needed
  programs.home-manager.enable = true;
  systemd.user.startServices = "sd-switch";
  home.stateVersion = "23.05";
}